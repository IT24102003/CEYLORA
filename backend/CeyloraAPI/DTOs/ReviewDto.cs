namespace CeyloraAPI.DTOs 
{ 
    public class CreateReviewDto 
    { 
        public int BookingId { get; set; } 
        public int Rating { get; set; } // 1 to 5 
        public string? Comment { get; set; } 
    } 
} 