using System.ComponentModel.DataAnnotations;

namespace CeyloraAPI.DTOs
{
    public class DestinationDto
    {
        [Required, MaxLength(150)]
        public string Name { get; set; } = string.Empty;

        [Required]
        public string Region { get; set; } = string.Empty;

        public string? Description { get; set; }
        public string? Category { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public string? ImageUrl { get; set; }
    }
}