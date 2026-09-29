namespace FoodReviewApi.Models;

public class ChatConversation
{
    public int Id { get; set; }
    public int RestaurantId { get; set; }
    public int CustomerId { get; set; }
    public int OwnerId { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public List<ChatMessage> Messages { get; set; } = new();
}

public class ChatMessage
{
    public int Id { get; set; }
    public int ConversationId { get; set; }
    public ChatConversation? Conversation { get; set; }
    public int SenderId { get; set; }
    public string Text { get; set; } = "";
    // Reservation notices have separate copy for the customer and restaurant owner.
    public string CustomerText { get; set; } = "";
    public string OwnerText { get; set; } = "";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public bool IsRead { get; set; }
}
