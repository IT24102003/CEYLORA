namespace CeyloraAPI.DTOs 
{ 
    public class VehicleDto 
    { 
        public int OperatorId { get; set; } 
        public string Type { get; set; } = string.Empty; 
        public int Capacity { get; set; } 
        public string Region { get; set; } = string.Empty; 
        public bool IsAvailable { get; set; } = true; 
    } 
}