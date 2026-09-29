namespace CeyloraAPI.DTOs
{
    public class AvailabilityCheckRequestDto
    {
        public DateTime CheckIn { get; set; }
        public DateTime CheckOut { get; set; }
        public int RoomsNeeded { get; set; } = 1;
    }

    public class AvailabilityCheckResponseDto
    {
        public bool IsAvailable { get; set; }
        public int RoomsAvailableForDates { get; set; }
        public decimal TotalPrice { get; set; }
        public int Nights { get; set; }
        public string Message { get; set; } = string.Empty;
    }
}