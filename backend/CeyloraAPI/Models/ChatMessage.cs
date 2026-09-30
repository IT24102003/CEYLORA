namespace CeyloraAPI.Models
{
    // A chat message between the Tourist and the Guide assigned to a Booking.
    public class ChatMessage
    {
        public int Id { get; set; }
        public int BookingId { get; set; }
        public Booking Booking { get; set; } = null!;

        public int SenderId { get; set; }
        public User Sender { get; set; } = null!;

        // Cached at send time so the UI doesn't need to re-resolve the sender's role ("Tourist"/"Guide"/"Admin")
        public string SenderRole { get; set; } = string.Empty;

        public string Message { get; set; } = string.Empty;
        public bool IsRead { get; set; } = false;
        public DateTime SentAt { get; set; } = DateTime.UtcNow;
    }
}
