using FoodReviewApi.Data;
using FoodReviewApi.DTOs;
using FoodReviewApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FoodReviewApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReviewsController : ControllerBase
{
    private readonly FoodReviewDbContext _context;
    private readonly IWebHostEnvironment _env;

    public ReviewsController(FoodReviewDbContext context, IWebHostEnvironment env)
    {
        _context = context;
        _env = env;
    }

    private async Task<User?> CurrentUser()
    {
        var userId = ApiSessions.Resolve(Request.Headers.Authorization.ToString());
        return userId == null ? null : await _context.Users.FindAsync(userId.Value);
    }

    private static bool IsAdmin(User user) =>
        user.Role.Equals("Admin", StringComparison.OrdinalIgnoreCase);

    private string PersistImageUrl(string value) => ImageStorage.PersistDataUrl(
        value,
        _env.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot"));

    // GET: api/reviews/restaurant/5
    [HttpGet("restaurant/{restaurantId}")]
    public async Task<ActionResult<IEnumerable<Review>>> GetReviewsForRestaurant(int restaurantId)
    {
        var reviews = await _context.Reviews
            .Include(r => r.Images)
            .Where(r => r.RestaurantId == restaurantId)
            .OrderByDescending(r => r.CreatedAt)
            .ToListAsync();

        return Ok(reviews);
    }

    // GET: api/reviews (all reviews for admin moderation)
    [HttpGet]
    public async Task<ActionResult<IEnumerable<Review>>> GetAllReviews()
    {
        var actor = await CurrentUser();
        if (actor == null) return Unauthorized();
        if (!IsAdmin(actor)) return StatusCode(StatusCodes.Status403Forbidden);

        var reviews = await _context.Reviews
            .Include(r => r.Images)
            .OrderByDescending(r => r.CreatedAt)
            .ToListAsync();

        return Ok(reviews);
    }

    // POST: api/reviews/upload — upload review image, returns URL
    [HttpPost("upload")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> UploadImage(IFormFile file)
    {
        if (await CurrentUser() == null)
            return Unauthorized(new { message = "Vui lòng đăng nhập để tải ảnh." });
        if (file == null || file.Length == 0)
            return BadRequest(new { message = "Không có file được gửi lên." });

        // Max 5 MB
        if (file.Length > 5 * 1024 * 1024)
            return BadRequest(new { message = "Ảnh không được vượt quá 5MB." });

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        var allowed = new[] { ".jpg", ".jpeg", ".png", ".webp", ".gif" };
        if (!allowed.Contains(ext))
            return BadRequest(new { message = "Chỉ chấp nhận file ảnh (jpg, png, webp, gif)." });

        var uploadsDir = Path.Combine(
            _env.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot"),
            "uploads");
        Directory.CreateDirectory(uploadsDir);

        var fileName = $"{Guid.NewGuid()}{ext}";
        var filePath = Path.Combine(uploadsDir, fileName);

        await using var stream = new FileStream(filePath, FileMode.Create);
        await file.CopyToAsync(stream);

        var url = $"/uploads/{fileName}";
        return Ok(new { url });
    }

    // POST: api/reviews
    [HttpPost]
    public async Task<ActionResult<Review>> CreateReview(CreateReviewDto dto)
    {
        var user = await CurrentUser();
        if (user == null)
            return Unauthorized(new { message = "Vui lòng đăng nhập để viết đánh giá!" });
        if (dto.ImageUrls.Count > 5)
            return BadRequest(new { message = "Mỗi đánh giá chỉ được đăng tối đa 5 ảnh." });

        // Serialize submissions for this restaurant across API instances.
        // Checking for a review and inserting it must be one atomic operation.
        await using var transaction = await _context.Database.BeginTransactionAsync();
        var restaurant = await _context.Restaurants
            .FromSqlInterpolated($"SELECT * FROM [Restaurants] WITH (UPDLOCK, HOLDLOCK) WHERE [Id] = {dto.RestaurantId}")
            .FirstOrDefaultAsync();
        if (restaurant == null)
            return NotFound(new { message = "Restaurant not found" });
        if (restaurant.OwnerId == user.Id)
            return StatusCode(StatusCodes.Status403Forbidden, new { message = "Chủ quán không thể đánh giá quán của mình." });

        if (await _context.Reviews.AnyAsync(r => r.RestaurantId == dto.RestaurantId && r.UserId == user.Id))
            return Conflict(new { message = "Bạn đã đánh giá quán này. Mỗi tài khoản chỉ được có một đánh giá trên mỗi quán. Hãy chỉnh sửa đánh giá đã đăng." });

        var review = new Review
        {
            RestaurantId = dto.RestaurantId,
            UserId = user.Id,
            UserName = user.FullName,
            UserAvatarUrl = string.IsNullOrWhiteSpace(user.AvatarUrl)
                ? $"https://i.pravatar.cc/150?u={user.Id}"
                : user.AvatarUrl,
            Rating = Math.Clamp(dto.Rating, 1.0, 5.0),
            Comment = dto.Comment,
            RecommendedDish = dto.RecommendedDish,
            ImageUrl = PersistImageUrl(dto.ImageUrl ?? ""),
            Images = dto.ImageUrls
                .Where(url => !string.IsNullOrWhiteSpace(url))
                .Select(url => new ReviewImage { ImageUrl = PersistImageUrl(url) })
                .ToList(),
            CreatedAt = DateTime.UtcNow
        };

        _context.Reviews.Add(review);
        await _context.SaveChangesAsync();

        var ratings = _context.Reviews.Where(r => r.RestaurantId == restaurant.Id);
        restaurant.ReviewCount = await ratings.CountAsync();
        restaurant.Rating = Math.Round(await ratings.AverageAsync(r => r.Rating), 1);

        await _context.SaveChangesAsync();
        await transaction.CommitAsync();

        return CreatedAtAction(nameof(GetReviewsForRestaurant), new { restaurantId = dto.RestaurantId }, review);
    }

    // PUT: api/reviews/5?userId=123
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateReview(int id, [FromBody] UpdateReviewDto dto)
    {
        var requester = await CurrentUser();
        if (requester == null) return Unauthorized(new { message = "Vui lòng đăng nhập!" });
        if (dto.ImageUrls?.Count > 5)
            return BadRequest(new { message = "Mỗi đánh giá chỉ được đăng tối đa 5 ảnh." });

        var review = await _context.Reviews
            .Include(r => r.Images)
            .FirstOrDefaultAsync(r => r.Id == id);
        if (review == null)
            return NotFound(new { message = "Đánh giá không tồn tại!" });

        bool isOwner = review.UserId == requester.Id;
        bool isAdminUser = IsAdmin(requester);

        if (!isOwner && !isAdminUser)
            return Forbid();

        var restaurantId = review.RestaurantId;

        // Update fields
        review.Rating = Math.Clamp(dto.Rating, 1.0, 5.0);
        review.Comment = dto.Comment;
        review.RecommendedDish = dto.RecommendedDish ?? review.RecommendedDish;
        review.ImageUrl = PersistImageUrl(dto.ImageUrl ?? review.ImageUrl);
        if (dto.ImageUrls != null)
        {
            review.Images = dto.ImageUrls
                .Where(url => !string.IsNullOrWhiteSpace(url))
                .Select(url => new ReviewImage { ImageUrl = PersistImageUrl(url) })
                .ToList();
        }

        await _context.SaveChangesAsync();

        // Recalculate restaurant rating
        var restaurant = await _context.Restaurants.Include(r => r.Reviews)
            .FirstOrDefaultAsync(r => r.Id == restaurantId);
        if (restaurant != null)
        {
            restaurant.ReviewCount = restaurant.Reviews.Count;
            restaurant.Rating = restaurant.Reviews.Count > 0
                ? Math.Round(restaurant.Reviews.Average(r => r.Rating), 1)
                : 5.0;
            await _context.SaveChangesAsync();
        }

        return Ok(review);
    }

    // DELETE: api/reviews/5?userId=123
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteReview(int id)
    {
        var requester = await CurrentUser();
        if (requester == null) return Unauthorized(new { message = "Vui lòng đăng nhập!" });
        var review = await _context.Reviews.FindAsync(id);
        if (review == null)
            return NotFound(new { message = "Đánh giá không tồn tại!" });

        var reviewRestaurant = await _context.Restaurants.FindAsync(review.RestaurantId);
        var canDelete = review.UserId == requester.Id || IsAdmin(requester) || reviewRestaurant?.OwnerId == requester.Id;
        if (!canDelete) return Forbid();

        // Delete local image if stored on server
        if (!string.IsNullOrEmpty(review.ImageUrl) && review.ImageUrl.Contains("/uploads/"))
        {
            var fileName = Path.GetFileName(review.ImageUrl);
            var filePath = Path.Combine(
                _env.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot"),
                "uploads", fileName);
            if (System.IO.File.Exists(filePath))
                System.IO.File.Delete(filePath);
        }

        var restaurantId = review.RestaurantId;
        _context.Reviews.Remove(review);
        await _context.SaveChangesAsync();

        // Recalculate rating for restaurant
        var restaurant = await _context.Restaurants.Include(r => r.Reviews)
            .FirstOrDefaultAsync(r => r.Id == restaurantId);
        if (restaurant != null)
        {
            restaurant.ReviewCount = restaurant.Reviews.Count;
            restaurant.Rating = restaurant.Reviews.Count > 0
                ? Math.Round(restaurant.Reviews.Average(r => r.Rating), 1)
                : 5.0;
            await _context.SaveChangesAsync();
        }

        return Ok(new { message = "Đã xóa đánh giá thành công!", id });
    }
}
