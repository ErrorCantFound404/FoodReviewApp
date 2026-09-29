using FoodReviewApi.Data;
using FoodReviewApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FoodReviewApi.Controllers;

[ApiController]
[Route("api/review-reports")]
public class ReviewReportsController(FoodReviewDbContext db) : ControllerBase
{
    private async Task<User?> Actor() {
        var id = ApiSessions.Resolve(Request.Headers.Authorization.ToString());
        return id == null ? null : await db.Users.FindAsync(id.Value);
    }
    public record ReportRequest(int ReviewId, string Reason);
    [HttpPost]
    public async Task<IActionResult> Create(ReportRequest request) {
        var actor = await Actor();
        if (actor == null) return Unauthorized(new { message = "Vui lòng đăng nhập lại." });
        if (string.IsNullOrWhiteSpace(request.Reason) || request.Reason.Trim().Length > 1000)
            return BadRequest(new { message = "Nhập lý do từ 1 đến 1000 ký tự." });
        var review = await db.Reviews.FindAsync(request.ReviewId);
        if (review == null) return NotFound(new { message = "Đánh giá không còn tồn tại." });
        var restaurant = await db.Restaurants.FindAsync(review.RestaurantId);
        if (restaurant?.OwnerId != actor.Id) return StatusCode(403);
        if (await db.ReviewReports.AnyAsync(r => r.ReviewId == review.Id && r.ReporterId == actor.Id && r.Status == "Pending"))
            return Conflict(new { message = "Đánh giá này đã được báo cáo và đang chờ xét duyệt." });
        db.ReviewReports.Add(new ReviewReport { ReviewId = review.Id, RestaurantId = review.RestaurantId, ReporterId = actor.Id, Reason = request.Reason.Trim() });
        try { await db.SaveChangesAsync(); }
        catch (DbUpdateException) { return Conflict(new { message = "Không thể gửi báo cáo. Hãy tải lại để kiểm tra." }); }
        return Ok(new { message = "Đã gửi báo cáo tới Admin." });
    }
    [HttpGet]
    public async Task<IActionResult> List() {
        var actor = await Actor();
        if (actor == null) return Unauthorized();
        if (actor.Role != "Admin") return StatusCode(403);
        var reports = await db.ReviewReports.AsNoTracking().Where(r => r.Status == "Pending").OrderBy(r => r.CreatedAt)
            .Select(r => new { r.Id, r.ReviewId, r.Reason, r.CreatedAt,
                RestaurantName = db.Restaurants.Where(x => x.Id == r.RestaurantId).Select(x => x.Name).FirstOrDefault(),
                ReporterName = db.Users.Where(x => x.Id == r.ReporterId).Select(x => x.FullName).FirstOrDefault()
            }).ToListAsync();
        var reviewIds = reports.Select(r => r.ReviewId).Distinct().ToArray();
        var reviews = await db.Reviews.AsNoTracking().Include(r => r.Images)
            .Where(r => reviewIds.Contains(r.Id)).ToDictionaryAsync(r => r.Id);
        return Ok(reports.Select(r => new { r.Id, r.Reason, r.CreatedAt, r.RestaurantName,
            r.ReporterName, Review = reviews.GetValueOrDefault(r.ReviewId) }));
    }
    [HttpPost("{id}/{decision}")]
    public async Task<IActionResult> Resolve(int id, string decision) {
        var actor = await Actor();
        if (actor == null) return Unauthorized();
        if (actor.Role != "Admin") return StatusCode(403);
        if (decision != "dismiss" && decision != "remove") return BadRequest();
        await using var transaction = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
        var report = await db.ReviewReports.FindAsync(id);
        if (report == null) return NotFound();
        if (report.Status != "Pending") return Conflict(new { message = "Báo cáo đã được xử lý." });
        if (decision == "remove") {
            var review = await db.Reviews.Include(r => r.Images).FirstOrDefaultAsync(r => r.Id == report.ReviewId);
            // A report references its review, so remove every report for the
            // review in the same transaction before deleting the review.
            // This prevents the foreign-key error that previously blocked
            // moderators from approving a removal.
            var relatedReports = await db.ReviewReports
                .Where(item => item.ReviewId == report.ReviewId)
                .ToListAsync();
            db.ReviewReports.RemoveRange(relatedReports);
            if (review != null)
            {
                db.ReviewImages.RemoveRange(review.Images);
                db.Reviews.Remove(review);
            }
            await db.SaveChangesAsync();
            var restaurant = await db.Restaurants.FindAsync(report.RestaurantId);
            if (restaurant != null) {
                var ratings = db.Reviews.Where(r => r.RestaurantId == restaurant.Id);
                restaurant.ReviewCount = await ratings.CountAsync();
                restaurant.Rating = Math.Round(await ratings.Select(r => (double?)r.Rating).AverageAsync() ?? 0, 1);
            }
        }
        else
        {
            report.Status = "Dismissed";
            report.ResolvedAt = DateTime.UtcNow;
            report.ResolvedBy = actor.Id;
        }
        await db.SaveChangesAsync();
        await transaction.CommitAsync();
        return Ok(new { message = decision == "remove" ? "Đã xóa đánh giá và cập nhật điểm quán." : "Đã bác báo cáo, giữ nguyên đánh giá." });
    }
}
