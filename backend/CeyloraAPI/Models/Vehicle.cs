namespace CeyloraAPI.Models
{
    public class Vehicle
    {
        public int Id { get; set; }
        public int OperatorId { get; set; }
        public User Operator { get; set; } = null!;
        public string Type { get; set; } = string.Empty;
        public int Capacity { get; set; }
        public string Region { get; set; } = string.Empty;
        public bool IsAvailable { get; set; } = true;

        public ICollection<VehicleImage> Images { get; set; } = new List<VehicleImage>();
    }
}