using FoodReviewApi.Data;
using FoodReviewApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FoodReviewApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReservationsController : ControllerBase
{
    private readonly FoodReviewDbContext _context;
    public ReservationsController(FoodReviewDbContext context) => _context = context;

    private async Task<User?> CurrentUser()
    {
        var userId = ApiSessions.Resolve(Request.Headers.Authorization.ToString());
        return userId == null ? null : await _context.Users.FindAsync(userId.Value);
    }

    [HttpPost]
    public async Task<ActionResult<Reservation>> Create(Reservation reservation)
    {
        var user = await CurrentUser();
        if (user == null)
            return Unauthorized(new { message = "Vui lòng đăng nhập lại để đặt bàn." });
        if (reservation.RestaurantId <= 0 || reservation.PartySize <= 0 ||
            string.IsNullOrWhiteSpace(reservation.CustomerName) || string.IsNullOrWhiteSpace(reservation.Phone))
            return BadRequest(new { message = "Vui lòng nhập đầy đủ thông tin đặt bàn." });

        var restaurant = await _context.Restaurants.FindAsync(reservation.RestaurantId);
        if (restaurant == null || !restaurant.IsOpen)
            return BadRequest(new { message = "Quán hiện không nhận đặt bàn." });
        if (restaurant.OwnerId == user.Id)
            return StatusCode(StatusCodes.Status403Forbidden, new { message = "Chủ quán không thể tự đặt bàn tại quán của mình." });
        if (reservation.ReservationTime <= DateTime.UtcNow)
            return BadRequest(new { message = "Thời gian đặt bàn phải ở tương lai." });

        await using var transaction = await _context.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
        var hasActiveReservation = await _context.Reservations.AnyAsync(item =>
            item.UserId == user.Id &&
            item.ReservationTime > DateTime.UtcNow &&
            (item.Status == "Pending" || item.Status == "Confirmed"));
        if (hasActiveReservation)
            return Conflict(new { message = "Bạn đang có một bàn chờ hoặc đã được xác nhận. Hãy hủy bàn đó trước khi đặt quán khác." });

        reservation.UserId = user.Id;
        reservation.Status = "Pending";
        reservation.CreatedAt = DateTime.UtcNow;
        _context.Reservations.Add(reservation);

        // A booking also creates (or reuses) the customer-to-owner chat so the
        // business account receives it in its normal inbox as an unread message.
        var conversation = await _context.ChatConversations.FirstOrDefaultAsync(item =>
            item.RestaurantId == restaurant.Id &&
            item.CustomerId == user.Id &&
            item.OwnerId == restaurant.OwnerId);
        if (conversation == null)
        {
            conversation = new ChatConversation
            {
                RestaurantId = restaurant.Id,
                CustomerId = user.Id,
                OwnerId = restaurant.OwnerId!.Value,
                UpdatedAt = reservation.CreatedAt
            };
            _context.ChatConversations.Add(conversation);
        }
        _context.ChatMessages.Add(new ChatMessage
        {
            Conversation = conversation,
            SenderId = user.Id,
            Text = "Thông báo đặt bàn mới.",
            CustomerText = $"Bạn đã đặt bàn tại quán {restaurant.Name}. Yêu cầu của bạn sẽ được chuyển cho chủ quán. Cảm ơn!",
            OwnerText = "Yêu cầu đặt bàn mới… Mở Quản lý quán ăn để xác nhận."
        });
        conversation.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        await transaction.CommitAsync();
        return CreatedAtAction(nameof(GetForRestaurant), new { restaurantId = reservation.RestaurantId }, reservation);
    }

    [HttpGet("mine")]
    public async Task<IActionResult> GetMine()
    {
        var user = await CurrentUser();
        if (user == null) return Unauthorized();
        return Ok(await _context.Reservations.AsNoTracking()
            .Where(item => item.UserId == user.Id)
            .OrderByDescending(item => item.ReservationTime)
            .Select(item => new {
                item.Id, item.RestaurantId, item.CustomerName, item.Phone,
                item.ReservationTime, item.PartySize, item.Note, item.Status, item.CreatedAt,
                RestaurantName = _context.Restaurants.Where(r => r.Id == item.RestaurantId).Select(r => r.Name).FirstOrDefault(),
            }).ToListAsync());
    }

    [HttpPost("{id}/cancel")]
    public async Task<IActionResult> Cancel(int id)
    {
        var user = await CurrentUser();
        if (user == null) return Unauthorized();
        var reservation = await _context.Reservations.FindAsync(id);
        if (reservation == null) return NotFound();
        if (reservation.UserId != user.Id) return StatusCode(StatusCodes.Status403Forbidden);
        if (reservation.Status is not ("Pending" or "Confirmed"))
            return Conflict(new { message = "Yêu cầu đặt bàn này không thể hủy." });
        if (reservation.ReservationTime <= DateTime.UtcNow)
            return Conflict(new { message = "Không thể hủy bàn khi giờ hẹn đã qua." });
        reservation.Status = "Cancelled";
        await _context.SaveChangesAsync();
        return Ok(reservation);
    }

    [HttpGet("restaurant/{restaurantId}")]
    public async Task<ActionResult<IEnumerable<Reservation>>> GetForRestaurant(int restaurantId)
    {
        var user = await CurrentUser();
        if (user == null) return Unauthorized();
        var restaurant = await _context.Restaurants.FindAsync(restaurantId);
        if (restaurant == null) return NotFound();
        if (restaurant.OwnerId != user.Id && !user.Role.Equals("Admin", StringComparison.OrdinalIgnoreCase))
            return StatusCode(StatusCodes.Status403Forbidden);
        return Ok(await _context.Reservations.Where(item => item.RestaurantId == restaurantId)
            .OrderBy(item => item.ReservationTime).ToListAsync());
    }

    [HttpPost("{id}/{status}")]
    public async Task<IActionResult> UpdateStatus(int id, string status)
    {
        if (status is not ("confirm" or "reject")) return BadRequest();
        var user = await CurrentUser();
        if (user == null) return Unauthorized();
        var reservation = await _context.Reservations.FindAsync(id);
        if (reservation == null) return NotFound();
        var restaurant = await _context.Restaurants.FindAsync(reservation.RestaurantId);
        if (restaurant?.OwnerId != user.Id && !user.Role.Equals("Admin", StringComparison.OrdinalIgnoreCase))
            return StatusCode(StatusCodes.Status403Forbidden);
        if (reservation.Status != "Pending")
            return Conflict(new { message = "Yêu cầu đặt bàn này đã được xử lý." });
        reservation.Status = status == "confirm" ? "Confirmed" : "Rejected";
        await _context.SaveChangesAsync();
        return Ok(reservation);
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteOld(int id)
    {
        var user = await CurrentUser();
        if (user == null) return Unauthorized();
        var reservation = await _context.Reservations.FindAsync(id);
        if (reservation == null) return NotFound();
        var restaurant = await _context.Restaurants.FindAsync(reservation.RestaurantId);
        if (restaurant?.OwnerId != user.Id && !user.Role.Equals("Admin", StringComparison.OrdinalIgnoreCase))
            return StatusCode(StatusCodes.Status403Forbidden);

        var stillActive = reservation.ReservationTime > DateTime.UtcNow &&
            (reservation.Status == "Pending" || reservation.Status == "Confirmed");
        if (stillActive)
            return Conflict(new { message = "Không thể xóa bàn đang chờ hoặc đã xác nhận trong tương lai." });
        _context.Reservations.Remove(reservation);
        await _context.SaveChangesAsync();
        return NoContent();
    }
}
