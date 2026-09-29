namespace FoodReviewApi.Models;

public class ReviewReport
{
    public int Id { get; set; }
    public int ReviewId { get; set; }
    public int RestaurantId { get; set; }
    public int ReporterId { get; set; }
    public string Reason { get; set; } = "";
    public string Status { get; set; } = "Pending";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public int? ResolvedBy { get; set; }
    public DateTime? ResolvedAt { get; set; }
}
