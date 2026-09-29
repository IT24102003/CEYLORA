namespace CeyloraAPI.DTOs
{
    public class UserProfileDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Role { get; set; } = string.Empty;
        public int? Age { get; set; }
        public string? Country { get; set; }
        public string? MobileNumber { get; set; }
        public string? ProfilePictureUrl { get; set; }
    }

    public class UpdateProfileDto
    {
        public string Name { get; set; } = string.Empty;
        public int? Age { get; set; }
        public string? Country { get; set; }
        public string? MobileNumber { get; set; }
    }
}