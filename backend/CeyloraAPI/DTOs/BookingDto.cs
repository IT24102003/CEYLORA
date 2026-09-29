namespace CeyloraAPI.DTOs
{
    public class CreateBookingDto
    {
        public int PackageId { get; set; }
        public DateTime TravelDate { get; set; }
        public int GroupSize { get; set; }
    }

    public class UpdateBookingStatusDto
    {
        public string Status { get; set; } = string.Empty; // Pending, Confirmed, Cancelled, Completed
    }
}