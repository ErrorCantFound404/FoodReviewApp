using FoodReviewApi.Data;
using FoodReviewApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FoodReviewApi.Controllers;

[ApiController]
[Route("api/chat")]
public class ChatController(FoodReviewDbContext db) : ControllerBase
{
    private async Task<int?> Actor()
    {
        var id = ApiSessions.Resolve(Request.Headers.Authorization.ToString());
        return id != null && await db.Users.AnyAsync(u => u.Id == id) ? id : null;
    }
    private IQueryable<ChatConversation> Accessible(int userId) => db.ChatConversations.Where(c =>
        (c.CustomerId == userId || c.OwnerId == userId) &&
        db.Restaurants.Any(r => r.Id == c.RestaurantId && r.OwnerId == c.OwnerId));

    [HttpGet]
    public async Task<IActionResult> Inbox()
    {
        var user = await Actor();
        if (user == null) return Unauthorized();
        return Ok(await Accessible(user.Value).OrderByDescending(c => c.UpdatedAt).Select(c => new {
            c.Id, c.RestaurantId, c.UpdatedAt,
            RestaurantName = db.Restaurants.Where(r => r.Id == c.RestaurantId).Select(r => r.Name).FirstOrDefault(),
            CustomerName = db.Users.Where(u => u.Id == c.CustomerId).Select(u => u.FullName).FirstOrDefault(),
            Unread = db.ChatMessages.Count(m => m.ConversationId == c.Id && m.SenderId != user.Value && !m.IsRead),
            LastMessage = db.ChatMessages.Where(m => m.ConversationId == c.Id).OrderByDescending(m => m.Id).Select(m => m.Text).FirstOrDefault()
        }).ToListAsync());
    }

    [HttpPost("restaurant/{restaurantId}")]
    public async Task<IActionResult> Start(int restaurantId)
    {
        var user = await Actor();
        if (user == null) return Unauthorized();
        var restaurant = await db.Restaurants.FindAsync(restaurantId);
        if (restaurant?.OwnerId == null) return BadRequest(new { message = "Quán chưa có chủ tài khoản để nhận tin nhắn." });
        if (restaurant.OwnerId == user) return BadRequest(new { message = "Bạn không thể nhắn tin cho chính mình." });
        var existing = await db.ChatConversations.FirstOrDefaultAsync(c => c.RestaurantId == restaurantId && c.CustomerId == user && c.OwnerId == restaurant.OwnerId);
        if (existing != null) return Ok(new { existing.Id });
        var conversation = new ChatConversation { RestaurantId = restaurantId, CustomerId = user.Value, OwnerId = restaurant.OwnerId.Value };
        db.ChatConversations.Add(conversation);
        try { await db.SaveChangesAsync(); }
        catch (DbUpdateException) {
            var concurrent = await db.ChatConversations.AsNoTracking().FirstOrDefaultAsync(c => c.RestaurantId == restaurantId && c.CustomerId == user && c.OwnerId == restaurant.OwnerId);
            if (concurrent == null) throw;
            return Ok(new { concurrent.Id });
        }
        return Ok(new { conversation.Id });
    }

    [HttpGet("{id}/messages")]
    public async Task<IActionResult> Messages(int id, int before = 0)
    {
        var user = await Actor();
        if (user == null) return Unauthorized();
        if (!await Accessible(user.Value).AnyAsync(c => c.Id == id)) return StatusCode(403);
        var messages = await db.ChatMessages.AsNoTracking().Where(m => m.ConversationId == id && (before == 0 || m.Id < before))
            .OrderByDescending(m => m.Id).Take(50).ToListAsync();
        return Ok(messages.OrderBy(m => m.Id));
    }

    public record ReadRequest(int ThroughId);
    [HttpPost("{id}/read")]
    public async Task<IActionResult> Read(int id, ReadRequest request)
    {
        var user = await Actor();
        if (user == null) return Unauthorized();
        if (!await Accessible(user.Value).AnyAsync(c => c.Id == id)) return StatusCode(403);
        await db.ChatMessages.Where(m => m.ConversationId == id && m.Id <= request.ThroughId && m.SenderId != user.Value && !m.IsRead)
            .ExecuteUpdateAsync(s => s.SetProperty(m => m.IsRead, true));
        return Ok(new { success = true });
    }

    public record SendRequest(string Text);
    [HttpPost("{id}/messages")]
    public async Task<IActionResult> Send(int id, SendRequest request)
    {
        var user = await Actor();
        if (user == null) return Unauthorized();
        if (string.IsNullOrWhiteSpace(request.Text) || request.Text.Trim().Length > 2000)
            return BadRequest(new { message = "Tin nhắn phải từ 1 đến 2000 ký tự." });
        var conversation = await Accessible(user.Value).FirstOrDefaultAsync(c => c.Id == id);
        if (conversation == null) return StatusCode(403);
        var message = new ChatMessage { ConversationId = id, SenderId = user.Value, Text = request.Text.Trim() };
        db.ChatMessages.Add(message);
        conversation.UpdatedAt = message.CreatedAt;
        await db.SaveChangesAsync();
        return Ok(message);
    }
}
