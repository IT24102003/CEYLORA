namespace CeyloraAPI.DTOs
{
    public class AuthResponseDto
    {
        public int UserId { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Role { get; set; } = string.Empty;
        public string Token { get; set; } = string.Empty;
        // false only for a Guide/VehicleOwner whose documents haven't been approved by an Admin yet.
        public bool IsVerified { get; set; } = true;
    }
}