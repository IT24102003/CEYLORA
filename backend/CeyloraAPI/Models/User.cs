namespace CeyloraAPI.Models
{
    // VehicleOwner MUST stay at the end — the int value is stored in the DB, and inserting
    // a new member earlier would silently reassign every existing Admin/Guide account's role.
    public enum UserRole { Tourist, Guide, Admin, VehicleOwner }

    public class User
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string PasswordHash { get; set; } = string.Empty;
        public UserRole Role { get; set; }
        public int? Age { get; set; }
        public string? Country { get; set; }
        public string? MobileNumber { get; set; }
        public string? ProfilePictureUrl { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}