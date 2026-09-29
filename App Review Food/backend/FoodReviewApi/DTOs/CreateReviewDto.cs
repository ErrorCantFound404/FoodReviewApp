namespace FoodReviewApi.DTOs;

public class CreateReviewDto
{
    public int RestaurantId { get; set; }
    public int? UserId { get; set; }
    public string UserName { get; set; } = "Anonymous Foodie";
    public string? UserAvatarUrl { get; set; }
    public double Rating { get; set; } = 5.0;
    public string Comment { get; set; } = string.Empty;
    public string RecommendedDish { get; set; } = string.Empty;
    public string ImageUrl { get; set; } = string.Empty;
    public List<string> ImageUrls { get; set; } = new();
}
