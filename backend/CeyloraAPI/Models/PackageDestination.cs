namespace CeyloraAPI.Models
{
    public class PackageDestination
    {
        public int Id { get; set; }
        public int PackageId { get; set; }
        public Package Package { get; set; } = null!;
        public int DestinationId { get; set; }
        public Destination Destination { get; set; } = null!;
        public int DayNumber { get; set; }
    }
}