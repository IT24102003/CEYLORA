namespace CeyloraAPI.Services
{
    // Fixed per-km rates by vehicle type (LKR/km), as agreed with the client:
    // Car = 120, Van = 180, Bus = 280 per km. Used to auto-price a self-registered
    // vehicle, and to estimate a Vehicle Owner's per-trip earnings.
    public static class VehiclePricing
    {
        public const decimal CarPerKm = 120m;
        public const decimal VanPerKm = 180m;
        public const decimal BusPerKm = 280m;

        public static decimal GetPricePerKm(string? vehicleType) => vehicleType?.Trim().ToLower() switch
        {
            "car" => CarPerKm,
            "van" => VanPerKm,
            "bus" => BusPerKm,
            _ => CarPerKm // sensible default for an unrecognized type
        };

        // The schema doesn't persist the actual distance driven per completed trip, so a
        // Vehicle Owner's per-trip earning is ESTIMATED as (per-km rate) x (assumed km/day)
        // x (trip duration in days). This constant is that assumption, kept in one place.
        public const double AssumedKmPerDay = 100;
    }
}
