namespace FoodReviewApi.DTOs;

public class UpdateReviewDto
{
    public double Rating { get; set; } = 5.0;
    public string Comment { get; set; } = string.Empty;
    public string? RecommendedDish { get; set; }
    public string? ImageUrl { get; set; }
    public List<string>? ImageUrls { get; set; }
}
