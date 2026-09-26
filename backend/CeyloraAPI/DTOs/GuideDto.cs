namespace CeyloraAPI.DTOs 
{ 
    public class GuideDto 
    { 
        public int UserId { get; set; } 
        public string? Languages { get; set; } 
        public string Region { get; set; } = string.Empty; 
        public bool IsAvailable { get; set; } = true; 
    } 
} 