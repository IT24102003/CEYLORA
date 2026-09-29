using System.ComponentModel.DataAnnotations;
using CeyloraAPI.Models;

namespace CeyloraAPI.DTOs
{
    public class RegisterDto
    {
        [Required, MaxLength(100)]
        public string Name { get; set; } = string.Empty;

        [Required, EmailAddress]
        public string Email { get; set; } = string.Empty;

        [Required, MinLength(6)]
        public string Password { get; set; } = string.Empty;

        [Required]
        public UserRole Role { get; set; }

        [Required]
        public string Country { get; set; } = string.Empty;

        [Required]
        public string MobileNumber { get; set; } = string.Empty;
    }
}