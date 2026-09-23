namespace CeyloraAPI.Models
{
    public enum PaymentStatus { Pending, Success, Failed }

    public class Payment
    {
        public int Id { get; set; }
        public int BookingId { get; set; }
        public Booking Booking { get; set; } = null!;
        public decimal Amount { get; set; }
        public PaymentStatus Status { get; set; } = PaymentStatus.Pending;
        public string Provider { get; set; } = "Sandbox";
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}