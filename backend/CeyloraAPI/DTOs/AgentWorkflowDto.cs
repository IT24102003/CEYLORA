namespace CeyloraAPI.DTOs
{
    public class StartWorkflowDto
    {
        public string Objective { get; set; } = string.Empty;
        public int? BookingId { get; set; }
    }

    public class WorkflowApprovalDto
    {
        public string ApprovalStatus { get; set; } = string.Empty;
    }

    public class ItineraryDayInputDto
    {
        public int DayNumber { get; set; }
        public string? Activities { get; set; }
        public string? Notes { get; set; }

        // Per-day selections (each day can have its own destinations & hotel).
        public List<int> DestinationIds { get; set; } = new();
        public int? HotelId { get; set; }
    }

    public class SubmitTripPlanDto
    {
        public string Objective { get; set; } = string.Empty;
        public int? BookingId { get; set; }

        // Aggregate (union across all days) — kept for backward compatibility / quick lookups.
        public List<int> DestinationIds { get; set; } = new();
        public int? HotelId { get; set; }

        // Trip-level selections (apply to the whole trip, not per-day).
        public int? GuideId { get; set; }
        public int? VehicleId { get; set; }

        public List<ItineraryDayInputDto> Days { get; set; } = new();

        // The cost estimate the tourist saw on the review screen, for admin visibility.
        public decimal? EstimatedTotalCost { get; set; }

        // When the tourist wants the trip to begin. Set by the tourist on the review screen
        // (calendar picker) when the AI's original prompt/objective didn't specify a date.
        public DateTime? PlannedStartDate { get; set; }
    }
}