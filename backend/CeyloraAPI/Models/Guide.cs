namespace CeyloraAPI.Models
{
    public class Guide
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public User User { get; set; } = null!;
        public string? Languages { get; set; }
        public string Region { get; set; } = string.Empty;
        public double Rating { get; set; } = 0;
        public bool IsAvailable { get; set; } = true;

        // ---- Verification (KYC) ----
        public string? NicNumber { get; set; }
        public string? TourismIdPhotoUrl { get; set; }
        // Defaults to true so existing/admin-linked guides (created before this feature, or
        // linked manually by an admin) keep working. Only the self-registration flow sets this
        // to false, requiring an admin to review the Tourism ID before the guide goes live.
        public bool IsVerified { get; set; } = true;
        public string? VerificationNote { get; set; }
    }
}