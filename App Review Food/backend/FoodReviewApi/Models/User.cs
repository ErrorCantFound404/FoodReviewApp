namespace FoodReviewApi.Models;

public class User
{
    public int Id { get; set; }
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string Role { get; set; } = "User"; // "Admin" or "User"
    public string AvatarUrl { get; set; } = string.Empty;
    public string? BusinessName { get; set; }
    public string? BusinessAddress { get; set; }
    public string? Email { get; set; }
    public string? BusinessType { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? LastLoginAt { get; set; }

    public List<Bookmark> Bookmarks { get; set; } = new();
}
