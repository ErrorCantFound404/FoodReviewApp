using System.ComponentModel.DataAnnotations.Schema;

namespace FoodReviewApi.Models;

public class Restaurant
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    
    // Category Relationship
    public int? CategoryId { get; set; }
    public Category? Category { get; set; }

    public string Cuisine { get; set; } = string.Empty;
    public string PriceRange { get; set; } = "50.000đ - 200.000đ"; // < 50.000đ, 50.000đ - 200.000đ, 200.000đ - 500.000đ, > 500.000đ
    public string CoverImageUrl { get; set; } = string.Empty;
    public double Rating { get; set; } = 5.0;
    public int ReviewCount { get; set; } = 0;
    public double Latitude { get; set; } = 21.0285;
    public double Longitude { get; set; } = 105.8542;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public string ApprovalStatus { get; set; } = "Draft";
    public DateTime? SubmittedAt { get; set; }
    public int? OwnerId { get; set; }
    public bool IsOpen { get; set; } = true;
    [NotMapped]
    public int BookmarkCount { get; set; }

    public List<Review> Reviews { get; set; } = new();
    public List<RestaurantImage> Images { get; set; } = new();
    public List<MenuItem> MenuItems { get; set; } = new();
}
