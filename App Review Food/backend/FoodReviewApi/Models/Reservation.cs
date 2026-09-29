namespace FoodReviewApi.Models;

public class Reservation
{
    public int Id { get; set; }
    public int RestaurantId { get; set; }
    public int UserId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
    public DateTime ReservationTime { get; set; }
    public int PartySize { get; set; }
    public string Note { get; set; } = string.Empty;
    public string Status { get; set; } = "Pending";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
