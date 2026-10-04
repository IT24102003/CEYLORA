namespace CeyloraAPI.DTOs
{
    // What a Vehicle Owner is allowed to edit on their own vehicle from the mobile app.
    // Type and PricePerKm are left out on purpose — they drive the fixed per-type business
    // pricing (see VehiclePricing) and stay Admin-controlled. Availability has its own
    // dedicated toggle endpoint (PUT /api/vehicles/{id}/availability).
    public class VehicleOwnerUpdateDto
    {
        public string? Name { get; set; }
        public int? ManufacturerYear { get; set; }
        public int Capacity { get; set; }
        public string Region { get; set; } = string.Empty;
    }
}
