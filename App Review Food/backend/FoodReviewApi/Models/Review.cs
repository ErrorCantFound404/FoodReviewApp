namespace FoodReviewApi.Models;

public class Review
{
    public int Id { get; set; }
    public int RestaurantId { get; set; }
    public int? UserId { get; set; }
    public User? User { get; set; }
    public string UserName { get; set; } = string.Empty;
    public string UserAvatarUrl { get; set; } = string.Empty;
    public double Rating { get; set; } = 5.0;
    public string Comment { get; set; } = string.Empty;
    public string RecommendedDish { get; set; } = string.Empty;
    public string ImageUrl { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public List<ReviewImage> Images { get; set; } = new();
}
