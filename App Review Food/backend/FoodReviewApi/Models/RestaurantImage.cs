namespace FoodReviewApi.Models;

public class RestaurantImage
{
    public int Id { get; set; }
    public int RestaurantId { get; set; }
    public string ImageUrl { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
