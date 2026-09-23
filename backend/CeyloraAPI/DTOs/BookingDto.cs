using CeyloraAPI.Models;

namespace CeyloraAPI.DTOs
{
    public class ManualBookingCreateDto
    {
        public int PackageId { get; set; }
        public int? HotelId { get; set; }
        public DateTime? CheckIn { get; set; }
        public DateTime? CheckOut { get; set; }
        public int GroupSize { get; set; } = 1;
    }

    public class BookingResponseDto
    {
        public int Id { get; set; }
        public int TouristId { get; set; }
        public string TouristName { get; set; } = string.Empty;
        public int PackageId { get; set; }
        public string PackageName { get; set; } = string.Empty;
        public BookingStatus Status { get; set; }
        public decimal TotalPrice { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
