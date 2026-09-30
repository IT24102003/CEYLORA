namespace CeyloraAPI.Models
{
    // Profile for a User with Role=VehicleOwner. Their vehicles are the Vehicle rows
    // whose OperatorId == this.UserId (Vehicle already had an OperatorId -> User link).
    public class VehicleOwner
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public User User { get; set; } = null!;

        public string Region { get; set; } = string.Empty;
        public string? NicNumber { get; set; }
        public string? DrivingLicensePhotoUrl { get; set; }

        // Defaults to true for the same reason as Guide.IsVerified — only the self-registration
        // flow (which collects the license photo) sets this false pending admin review.
        public bool IsVerified { get; set; } = true;
        public string? VerificationNote { get; set; }
    }
}
