namespace CeyloraAPI.DTOs
{
    public class CreateItineraryDayDto
    {
        public int DayNumber { get; set; }
        public string? ActivitiesJson { get; set; }
        public string? Notes { get; set; }
    }

    public class CreateItineraryDto
    {
        public int BookingId { get; set; }
        public string GeneratedBy { get; set; } = "Manual"; // "AI" or "Manual"
        public List<CreateItineraryDayDto> Days { get; set; } = new();
    }

    public class UpdateApprovalStatusDto
    {
        public string ApprovalStatus { get; set; } = string.Empty; // Approved, Rejected, RevisionRequested
    }
}