namespace CeyloraAPI.Models
{
    public static class NotificationType
    {
        public const string Welcome = "Welcome";
        public const string BookingApproved = "BookingApproved";
        public const string BookingCancelled = "BookingCancelled";
        public const string PaymentConfirmed = "PaymentConfirmed";
        public const string AIWorkflow = "AIWorkflow";
        public const string ChatMessage = "ChatMessage";
        public const string General = "General";
    }

    public class Notification
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public User User { get; set; } = null!;
        public string Title { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
        public string Type { get; set; } = NotificationType.General;
        public bool IsRead { get; set; } = false;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
