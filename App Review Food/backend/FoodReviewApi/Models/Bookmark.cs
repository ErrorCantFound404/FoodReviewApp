namespace FoodReviewApi.Models;

public class Bookmark
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public User? User { get; set; }

    public int RestaurantId { get; set; }
    public Restaurant? Restaurant { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
