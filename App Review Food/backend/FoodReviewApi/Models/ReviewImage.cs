namespace FoodReviewApi.Models;

public class ReviewImage
{
    public int Id { get; set; }
    public int ReviewId { get; set; }
    public string ImageUrl { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
