namespace CeyloraAPI.Models
{
    public class ItineraryDay
    {
        public int Id { get; set; }
        public int ItineraryId { get; set; }
        public Itinerary Itinerary { get; set; } = null!;
        public int DayNumber { get; set; }
        public string? ActivitiesJson { get; set; } // JSONB in Postgres
        public string? Notes { get; set; }
    }
}
