namespace CeyloraAPI.Models
{
    public enum HotelBookingStatus { Reserved, Confirmed, Cancelled }

    public class HotelBooking
    {
        public int Id { get; set; }
        public int BookingId { get; set; }
        public Booking Booking { get; set; } = null!;
        public int HotelId { get; set; }
        public Hotel Hotel { get; set; } = null!;
        public DateTime CheckIn { get; set; }
        public DateTime CheckOut { get; set; }
        public HotelBookingStatus Status { get; set; } = HotelBookingStatus.Reserved;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}