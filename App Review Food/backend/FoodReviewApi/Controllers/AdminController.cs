using FoodReviewApi.Data;
using FoodReviewApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FoodReviewApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AdminController : ControllerBase
{
    private readonly FoodReviewDbContext _context;

    public AdminController(FoodReviewDbContext context)
    {
        _context = context;
    }

    private async Task<User?> CurrentAdmin()
    {
        var userId = ApiSessions.Resolve(Request.Headers.Authorization.ToString());
        if (userId == null) return null;

        var user = await _context.Users.FindAsync(userId.Value);
        return user?.Role.Equals("Admin", StringComparison.OrdinalIgnoreCase) == true
            ? user
            : null;
    }

    // GET: api/admin/stats
    [HttpGet("stats")]
    public async Task<ActionResult<object>> GetAdminStats()
    {
        var admin = await CurrentAdmin();
        if (admin == null)
        {
            return ApiSessions.Resolve(Request.Headers.Authorization.ToString()) == null
                ? Unauthorized(new { message = "Vui lòng đăng nhập bằng tài khoản Admin." })
                : StatusCode(StatusCodes.Status403Forbidden, new { message = "Bạn không có quyền truy cập khu vực quản trị." });
        }

        var totalRestaurants = await _context.Restaurants.CountAsync();
        var totalReviews = await _context.Reviews.CountAsync();
        var totalBookmarks = await _context.Bookmarks.CountAsync();
        var totalCategories = await _context.Categories.CountAsync();
        var totalUsers = await _context.Users.CountAsync();
        var openRestaurants = await _context.Restaurants.CountAsync(r => r.IsOpen);
        var closedRestaurants = totalRestaurants - openRestaurants;

        var avgRating = totalRestaurants > 0
            ? Math.Round(await _context.Restaurants.AverageAsync(r => r.Rating), 1)
            : 0.0;

        var recentReviews = await _context.Reviews
            .OrderByDescending(r => r.CreatedAt)
            .Take(5)
            .ToListAsync();

        var latestReview = await _context.Reviews
            .OrderByDescending(r => r.CreatedAt)
            .Select(r => new
            {
                r.Id,
                r.RestaurantId,
                r.UserName,
                r.Comment,
                r.Rating,
                r.CreatedAt,
                RestaurantName = _context.Restaurants
                    .Where(restaurant => restaurant.Id == r.RestaurantId)
                    .Select(restaurant => restaurant.Name)
                    .FirstOrDefault()
            })
            .FirstOrDefaultAsync();

        return Ok(new
        {
            totalRestaurants,
            totalReviews,
            averageSystemRating = avgRating,
            totalBookmarks,
            totalCategories,
            totalUsers,
            openRestaurants,
            closedRestaurants,
            onlineUsers = ApiSessions.ActiveUserCount(),
            recentReviews,
            latestReview
        });
    }
}
