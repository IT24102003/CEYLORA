namespace CeyloraAPI.Models
{
    // Trip status shown on the Admin, Tourist, Guide and Vehicle Owner sides.
    // 🔥 "Completed" renamed to "Ended" and "OnGoing"/"Rejected" added at the END (existing
    // members keep their original int value, so no DB migration is needed — only the C#
    // names/labels changed, plus two new values).
    public enum BookingStatus { Pending, Confirmed, Cancelled, Ended, OnGoing, Rejected }

    public class Booking
    {
        public int Id { get; set; }
        public int TouristId { get; set; }
        public User Tourist { get; set; } = null!;

        // Nullable because a booking can now come from the AI "Plan My Trip" customize
        // flow, which isn't built from an existing Package — it's a from-scratch itinerary
        // the tourist assembled themselves (destinations/hotel/guide/vehicle per day).
        public int? PackageId { get; set; }
        public Package? Package { get; set; }

        // Set only for a custom AI-planned trip (PackageId == null), so screens still have
        // a name and duration to show instead of a real Package's.
        public string? CustomTripObjective { get; set; }
        public int? CustomTripDurationDays { get; set; }

        // Short, human-friendly auto-generated name for an AI-planned trip (e.g. "Kandy &
        // Ella 5-Day Trip"), set once at submit time (AgentWorkflowController.SubmitPlan) so
        // lists/chat/etc. have something nicer to show than the raw free-text objective.
        public string? CustomTripName { get; set; }

        public BookingStatus Status { get; set; } = BookingStatus.Pending;

        // True once a Payment has been recorded for this booking. For a package purchase,
        // payment happens right after booking creation but must NOT auto-confirm the trip —
        // the admin still has to assign a guide/vehicle (AssignmentsController.AssignAndConfirm
        // requires IsPaid=true for package bookings before it will let that happen). For an
        // AI-planned trip, IsPaid stays false until the tourist pays from their Profile AFTER
        // the admin has already approved & confirmed it.
        public bool IsPaid { get; set; } = false;

        // How many people this trip is for — set from CreateBookingDto.GroupSize when a
        // tourist books a Package. Used by the Admin panel to pick a vehicle whose Capacity
        // is big enough when assigning a guide/vehicle and confirming the trip.
        public int GroupSize { get; set; } = 1;

        // When the tourist wants the trip to begin — chosen on the trip-plan review screen
        // (calendar picker) at submit time. Different from TripStartedAt below: this is the
        // tourist's PLANNED date, TripStartedAt is when the Guide actually pressed "Start Trip".
        public DateTime? PlannedStartDate { get; set; }

        // Set when the Guide taps "Start Trip" — used to stop them ending the trip before
        // its full duration has actually elapsed (e.g. a 2-day trip started 2026-09-30 can
        // only be ended on/after 2026-10-01).
        public DateTime? TripStartedAt { get; set; }

        public decimal TotalPrice { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}