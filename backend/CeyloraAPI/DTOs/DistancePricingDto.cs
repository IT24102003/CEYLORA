namespace CeyloraAPI.DTOs
{
    public class DistanceQuoteRequestDto
    {
        public double StartLat { get; set; }
        public double StartLon { get; set; }
        public double EndLat { get; set; }
        public double EndLon { get; set; }
        public int VehicleId { get; set; }
    }

    public class DistanceQuoteResponseDto
    {
        public double DistanceKm { get; set; }
        public decimal PricePerKm { get; set; }
        public decimal TotalVehicleCharge { get; set; }
    }
}