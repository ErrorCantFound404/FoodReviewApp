using FoodReviewApi.Data;
using FoodReviewApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FoodReviewApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class RestaurantsController : ControllerBase
{
    private readonly FoodReviewDbContext _context;
    private readonly IWebHostEnvironment _environment;

    public RestaurantsController(FoodReviewDbContext context, IWebHostEnvironment environment)
    {
        _context = context;
        _environment = environment;
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
        _environment.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot"));

    // GET: api/restaurants
    [HttpGet]
    public async Task<ActionResult<IEnumerable<Restaurant>>> GetRestaurants([FromQuery] string? category, [FromQuery] string? search, [FromQuery] bool includeUnapproved = false, [FromQuery] int? ownerId = null, [FromQuery] bool businessOnly = false)
    {
        var actor = await CurrentUser();
        var canSeeAllUnapproved = actor != null && IsAdmin(actor);
        // The home/search endpoint must stay lightweight. Gallery images,
        // reviews and menu data are loaded only by GET /api/restaurants/{id}.
        var query = _context.Restaurants
            .Include(r => r.Category)
            .AsNoTracking()
            .AsQueryable();

        if (!includeUnapproved || actor == null)
        {
            query = query.Where(r => r.ApprovalStatus == "Approved");
        }
        else if (!canSeeAllUnapproved)
        {
            query = query.Where(r => r.ApprovalStatus == "Approved" || r.OwnerId == actor.Id);
        }
        if (ownerId != null)
        {
            query = query.Where(r => r.OwnerId == ownerId);
        }
        if (businessOnly)
        {
            query = query.Where(r => r.OwnerId != null &&
                _context.Users.Any(user => user.Id == r.OwnerId && user.Role == "Business"));
        }

        if (!string.IsNullOrWhiteSpace(category) && category != "All")
        {
            query = query.Where(r => r.Cuisine.ToLower() == category.ToLower() || (r.Category != null && r.Category.Name.ToLower() == category.ToLower()));
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.ToLower();
            query = query.Where(r => r.Name.ToLower().Contains(term) ||
                                     r.Description.ToLower().Contains(term) ||
                                     r.Address.ToLower().Contains(term) ||
                                     r.Cuisine.ToLower().Contains(term) ||
                                     (r.Category != null && r.Category.Name.ToLower().Contains(term)));
        }

        var list = await query
            .OrderByDescending(r => r.Rating)
            .Select(r => new
            {
                r.Id,
                r.Name,
                r.Description,
                r.Address,
                r.CategoryId,
                r.Cuisine,
                r.PriceRange,
                // Never include large base64 data in the list JSON. The card
                // loads it lazily through the image endpoint instead.
                CoverImageUrl = r.CoverImageUrl.StartsWith("data:image/") ? string.Empty : r.CoverImageUrl,
                CardImageUrl = r.CoverImageUrl.StartsWith("data:image/") ? $"/api/restaurants/{r.Id}/cover" : r.CoverImageUrl,
                r.Rating,
                ReviewCount = r.Reviews.Count(),
                r.Latitude,
                r.Longitude,
                r.CreatedAt,
                r.ApprovalStatus,
                r.SubmittedAt,
                r.OwnerId,
                r.IsOpen
            })
            .ToListAsync();
        return Ok(list);
    }

    // GET: api/restaurants/5/cover
    // Serves embedded cover images separately from the list response so they
    // do not block JSON parsing and input interactions in the web client.
    [HttpGet("{id}/cover")]
    public async Task<IActionResult> GetRestaurantCover(int id)
    {
        var coverImageUrl = await _context.Restaurants
            .AsNoTracking()
            .Where(r => r.Id == id)
            .Select(r => r.CoverImageUrl)
            .FirstOrDefaultAsync();

        if (string.IsNullOrWhiteSpace(coverImageUrl)) return NotFound();
        if (!coverImageUrl.StartsWith("data:image/")) return Redirect(coverImageUrl);

        var separatorIndex = coverImageUrl.IndexOf(',');
        if (separatorIndex < 0) return BadRequest(new { message = "Invalid image data." });

        try
        {
            var metadata = coverImageUrl[..separatorIndex];
            var mimeType = metadata[5..].Split(';')[0];
            if (!mimeType.StartsWith("image/")) return BadRequest(new { message = "Unsupported image type." });

            Response.Headers.CacheControl = "public,max-age=604800,immutable";
            return File(Convert.FromBase64String(coverImageUrl[(separatorIndex + 1)..]), mimeType);
        }
        catch (FormatException)
        {
            return BadRequest(new { message = "Invalid image data." });
        }
    }

    // POST: api/restaurants/5/submit
    [HttpPost("{id}/submit")]
    public async Task<IActionResult> SubmitRestaurantProfile(int id)
    {
        var actor = await CurrentUser();
        if (actor == null) return Unauthorized(new { message = "Vui lòng đăng nhập lại." });
        var restaurant = await _context.Restaurants.FindAsync(id);
        if (restaurant == null) return NotFound(new { message = "Restaurant not found" });
        if (restaurant.OwnerId != actor.Id && !IsAdmin(actor))
            return StatusCode(StatusCodes.Status403Forbidden, new { message = "Bạn không có quyền gửi hồ sơ quán này." });

        restaurant.ApprovalStatus = "Pending";
        restaurant.SubmittedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return Ok(new { message = "Hồ sơ đã được gửi tới quản trị viên.", approvalStatus = restaurant.ApprovalStatus });
    }

    [HttpPost("{id}/approve")]
    public async Task<IActionResult> ApproveRestaurantProfile(int id)
    {
        var actor = await CurrentUser();
        if (actor == null) return Unauthorized(new { message = "Vui lòng đăng nhập lại." });
        if (!IsAdmin(actor)) return StatusCode(StatusCodes.Status403Forbidden);
        var restaurant = await _context.Restaurants.FindAsync(id);
        if (restaurant == null) return NotFound();
        restaurant.ApprovalStatus = "Approved";
        await _context.SaveChangesAsync();
        return Ok(new { message = "Đã phê duyệt hồ sơ nhà hàng." });
    }

    [HttpPost("{id}/reject")]
    public async Task<IActionResult> RejectRestaurantProfile(int id)
    {
        var actor = await CurrentUser();
        if (actor == null) return Unauthorized(new { message = "Vui lòng đăng nhập lại." });
        if (!IsAdmin(actor)) return StatusCode(StatusCodes.Status403Forbidden);
        var restaurant = await _context.Restaurants.FindAsync(id);
        if (restaurant == null) return NotFound();
        restaurant.ApprovalStatus = "Rejected";
        await _context.SaveChangesAsync();
        return Ok(new { message = "Đã từ chối hồ sơ nhà hàng." });
    }

    // GET: api/restaurants/5
    [HttpGet("{id}")]
    public async Task<ActionResult<Restaurant>> GetRestaurant(int id)
    {
        var actor = await CurrentUser();
        var restaurant = await _context.Restaurants
            .Include(r => r.Reviews)
                .ThenInclude(review => review.Images)
            .Include(r => r.Images)
            .Include(r => r.MenuItems)
            .Include(r => r.Category)
            .FirstOrDefaultAsync(r => r.Id == id);

        if (restaurant == null)
        {
            return NotFound();
        }
        if (restaurant.ApprovalStatus != "Approved" &&
            (actor == null || (restaurant.OwnerId != actor.Id && !IsAdmin(actor))))
        {
            return NotFound();
        }

        restaurant.BookmarkCount = await _context.Bookmarks
            .CountAsync(bookmark => bookmark.RestaurantId == restaurant.Id);
        restaurant.Reviews = restaurant.Reviews.OrderByDescending(r => r.CreatedAt).ToList();
        return Ok(restaurant);
    }

    // POST: api/restaurants
    [HttpPost]
    public async Task<ActionResult<Restaurant>> CreateRestaurant(Restaurant restaurant)
    {
        var actor = await CurrentUser();
        if (actor == null) return Unauthorized(new { message = "Vui lòng đăng nhập lại." });
        if (!IsAdmin(actor) && !actor.Role.Equals("Business", StringComparison.OrdinalIgnoreCase))
            return StatusCode(StatusCodes.Status403Forbidden, new { message = "Chỉ Admin hoặc tài khoản doanh nghiệp có thể tạo quán." });

        if (restaurant.Images.Count > 5)
        {
            return BadRequest(new { message = "Mỗi quán chỉ được đăng tối đa 5 ảnh." });
        }
        restaurant.CoverImageUrl = PersistImageUrl(restaurant.CoverImageUrl);
        foreach (var image in restaurant.Images)
            image.ImageUrl = PersistImageUrl(image.ImageUrl);
        foreach (var item in restaurant.MenuItems)
            item.ImageUrl = PersistImageUrl(item.ImageUrl);

        if (restaurant.CategoryId != null)
        {
            var cat = await _context.Categories.FindAsync(restaurant.CategoryId.Value);
            if (cat != null)
            {
                restaurant.Cuisine = cat.Name;
            }
        }
        else if (!string.IsNullOrWhiteSpace(restaurant.Cuisine))
        {
            var cat = await _context.Categories.FirstOrDefaultAsync(c => c.Name.ToLower() == restaurant.Cuisine.ToLower());
            if (cat != null)
            {
                restaurant.CategoryId = cat.Id;
            }
        }

        // Restaurants created from the Admin dashboard do not carry an owner
        // in the client payload. Assign the first Admin account explicitly so
        // the record has a consistent owner and approval audit trail.
        User? owner;
        if (IsAdmin(actor) && restaurant.OwnerId.HasValue)
        {
            owner = await _context.Users.FindAsync(restaurant.OwnerId.Value);
        }
        else
        {
            owner = actor;
            restaurant.OwnerId = actor.Id;
        }

        if (owner?.Role == "Admin")
        {
            restaurant.ApprovalStatus = "Approved";
            restaurant.SubmittedAt ??= DateTime.UtcNow;
        }

        _context.Restaurants.Add(restaurant);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetRestaurant), new { id = restaurant.Id }, restaurant);
    }

    // PUT: api/restaurants/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateRestaurant(int id, Restaurant updatedRestaurant)
    {
        var actor = await CurrentUser();
        if (actor == null) return Unauthorized(new { message = "Vui lòng đăng nhập lại." });
        if (id != updatedRestaurant.Id)
        {
            return BadRequest(new { message = "Id mismatch" });
        }

        if (updatedRestaurant.Images.Count > 5)
        {
            return BadRequest(new { message = "Mỗi quán chỉ được đăng tối đa 5 ảnh." });
        }

        var existing = await _context.Restaurants
            .Include(r => r.Images)
            .Include(r => r.MenuItems)
            .FirstOrDefaultAsync(r => r.Id == id);
        if (existing == null)
        {
            return NotFound(new { message = "Restaurant not found" });
        }
        if (existing.OwnerId != actor.Id && !IsAdmin(actor))
            return StatusCode(StatusCodes.Status403Forbidden, new { message = "Bạn không có quyền chỉnh sửa quán này." });

        existing.Name = updatedRestaurant.Name;
        existing.Description = updatedRestaurant.Description;
        existing.Address = updatedRestaurant.Address;
        existing.CategoryId = updatedRestaurant.CategoryId;
        existing.Cuisine = updatedRestaurant.Cuisine;

        if (updatedRestaurant.CategoryId != null)
        {
            var cat = await _context.Categories.FindAsync(updatedRestaurant.CategoryId.Value);
            if (cat != null)
            {
                existing.Cuisine = cat.Name;
            }
        }
        else if (!string.IsNullOrWhiteSpace(updatedRestaurant.Cuisine))
        {
            var cat = await _context.Categories.FirstOrDefaultAsync(c => c.Name.ToLower() == updatedRestaurant.Cuisine.ToLower());
            if (cat != null)
            {
                existing.CategoryId = cat.Id;
            }
        }

        existing.PriceRange = updatedRestaurant.PriceRange;
        existing.IsOpen = updatedRestaurant.IsOpen;
        existing.CoverImageUrl = PersistImageUrl(updatedRestaurant.CoverImageUrl);
        existing.Images = updatedRestaurant.Images
            .Where(image => !string.IsNullOrWhiteSpace(image.ImageUrl))
            .Select(image => new RestaurantImage { ImageUrl = PersistImageUrl(image.ImageUrl) })
            .ToList();
        existing.MenuItems = updatedRestaurant.MenuItems
            .Where(item => !string.IsNullOrWhiteSpace(item.Name) && item.Price >= 0)
            .Select((item, index) => new MenuItem
            {
                Name = item.Name,
                Description = item.Description,
                Price = item.Price,
                ImageUrl = PersistImageUrl(item.ImageUrl),
                IsAvailable = item.IsAvailable,
                DisplayOrder = index
            })
            .ToList();
        existing.Latitude = updatedRestaurant.Latitude;
        existing.Longitude = updatedRestaurant.Longitude;

        await _context.SaveChangesAsync();
        return Ok(existing);
    }

    // DELETE: api/restaurants/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteRestaurant(int id)
    {
        var actor = await CurrentUser();
        if (actor == null) return Unauthorized(new { message = "Vui lòng đăng nhập lại." });
        var restaurant = await _context.Restaurants.FindAsync(id);
        if (restaurant == null)
        {
            return NotFound(new { message = "Restaurant not found" });
        }
        if (restaurant.OwnerId != actor.Id && !IsAdmin(actor))
            return StatusCode(StatusCodes.Status403Forbidden, new { message = "Bạn không có quyền xóa quán này." });

        _context.Restaurants.Remove(restaurant);
        await _context.SaveChangesAsync();
        return Ok(new { message = "Restaurant deleted successfully", id });
    }
}
