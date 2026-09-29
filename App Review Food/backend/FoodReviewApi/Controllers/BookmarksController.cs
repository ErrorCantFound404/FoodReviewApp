using FoodReviewApi.Data;
using FoodReviewApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FoodReviewApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class BookmarksController : ControllerBase
{
    private readonly FoodReviewDbContext _context;

    public BookmarksController(FoodReviewDbContext context)
    {
        _context = context;
    }

    private async Task<User?> CurrentUser()
    {
        var userId = ApiSessions.Resolve(Request.Headers.Authorization.ToString());
        return userId == null ? null : await _context.Users.FindAsync(userId.Value);
    }

    // GET: api/bookmarks?userId=1
    [HttpGet]
    public async Task<ActionResult<IEnumerable<Restaurant>>> GetBookmarks([FromQuery] int? userId)
    {
        var user = await CurrentUser();
        if (user == null) return Unauthorized(new { message = "Vui lòng đăng nhập để xem bookmark." });

        var bookmarkedIds = await _context.Bookmarks
            .Where(b => b.UserId == user.Id)
            .Select(b => b.RestaurantId)
            .ToListAsync();

        var restaurants = await _context.Restaurants
            .Include(r => r.Reviews)
            .Include(r => r.Category)
            .Where(r => bookmarkedIds.Contains(r.Id))
            .ToListAsync();

        return Ok(restaurants);
    }

    // GET: api/bookmarks/ids?userId=1
    [HttpGet("ids")]
    public async Task<ActionResult<IEnumerable<int>>> GetBookmarkedIds([FromQuery] int? userId)
    {
        var user = await CurrentUser();
        if (user == null) return Unauthorized(new { message = "Vui lòng đăng nhập để xem bookmark." });

        var bookmarkedIds = await _context.Bookmarks
            .Where(b => b.UserId == user.Id)
            .Select(b => b.RestaurantId)
            .ToListAsync();

        return Ok(bookmarkedIds);
    }

    // POST: api/bookmarks/toggle/5?userId=1
    [HttpPost("toggle/{restaurantId}")]
    public async Task<ActionResult<object>> ToggleBookmark(int restaurantId, [FromQuery] int? userId)
    {
        var user = await CurrentUser();
        if (user == null) return Unauthorized(new { message = "Vui lòng đăng nhập để lưu vào bookmark!" });

        var restaurant = await _context.Restaurants.FindAsync(restaurantId);
        if (restaurant == null)
        {
            return NotFound(new { message = "Không tìm thấy nhà hàng này" });
        }

        var existing = await _context.Bookmarks
            .FirstOrDefaultAsync(b => b.RestaurantId == restaurantId && b.UserId == user.Id);
        bool isBookmarked;

        if (existing != null)
        {
            _context.Bookmarks.Remove(existing);
            isBookmarked = false;
        }
        else
        {
            _context.Bookmarks.Add(new Bookmark
            {
                RestaurantId = restaurantId,
                UserId = user.Id,
                CreatedAt = DateTime.UtcNow
            });
            isBookmarked = true;
        }

        await _context.SaveChangesAsync();
        return Ok(new { restaurantId, isBookmarked });
    }
}
