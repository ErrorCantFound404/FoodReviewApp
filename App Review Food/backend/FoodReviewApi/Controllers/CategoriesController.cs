using FoodReviewApi.Data;
using FoodReviewApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FoodReviewApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CategoriesController : ControllerBase
{
    private readonly FoodReviewDbContext _context;

    public CategoriesController(FoodReviewDbContext context)
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

    // GET: api/categories
    [HttpGet]
    public async Task<ActionResult<IEnumerable<Category>>> GetCategories()
    {
        var categories = await _context.Categories.ToListAsync();
        return Ok(categories);
    }

    // POST: api/categories
    [HttpPost]
    public async Task<ActionResult<Category>> CreateCategory([FromBody] Category category)
    {
        if (await CurrentAdmin() == null)
            return StatusCode(StatusCodes.Status403Forbidden, new { message = "Chỉ Admin mới có thể tạo thể loại." });
        if (string.IsNullOrWhiteSpace(category.Name))
        {
            return BadRequest(new { message = "Tên thể loại không được để trống" });
        }

        category.CreatedAt = DateTime.UtcNow;
        _context.Categories.Add(category);
        await _context.SaveChangesAsync();

        return Ok(category);
    }

    // DELETE: api/categories/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteCategory(int id)
    {
        if (await CurrentAdmin() == null)
            return StatusCode(StatusCodes.Status403Forbidden, new { message = "Chỉ Admin mới có thể xóa thể loại." });
        var category = await _context.Categories.FindAsync(id);
        if (category == null)
        {
            return NotFound(new { message = "Không tìm thấy thể loại này" });
        }

        // Check if any restaurant is currently using this category
        var isUsed = await _context.Restaurants.AnyAsync(r => r.CategoryId == category.Id || r.Cuisine.ToLower() == category.Name.ToLower());
        if (isUsed)
        {
            return BadRequest(new { message = $"Không được phép xóa thể loại '{category.Name}' vì đang có nhà hàng thuộc thể loại này!" });
        }

        _context.Categories.Remove(category);
        await _context.SaveChangesAsync();
        return Ok(new { message = "Đã xóa thể loại thành công", id });
    }
}
