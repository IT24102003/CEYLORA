namespace CeyloraAPI.DTOs 
{ 
    public class AutoMatchRequestDto 
    { 
        public int BookingId { get; set; } 
        public string Region { get; set; } = string.Empty; 
        public string? PreferredLanguage { get; set; } 
    } 
  
    public class AssignmentResultDto 
    { 
        public int? AssignmentId { get; set; } 
        public int? GuideId { get; set; } 
        public string? GuideName { get; set; } 
        public int? VehicleId { get; set; } 
        public string? VehicleType { get; set; } 
        public bool Success { get; set; } 
        public string Message { get; set; } = string.Empty; 
    } 
  
    public class UpdateAssignmentStatusDto 
    { 
        public string Status { get; set; } = string.Empty; // Proposed, Confirmed, Cancelled 
    } 
} 