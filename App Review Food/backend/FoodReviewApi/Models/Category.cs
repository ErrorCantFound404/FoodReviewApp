namespace FoodReviewApi.Models;

public class Category
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Icon { get; set; } = "utensils";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public List<Restaurant> Restaurants { get; set; } = new();
}
