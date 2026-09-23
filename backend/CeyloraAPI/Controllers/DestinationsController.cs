using CeyloraAPI.Data;
using CeyloraAPI.DTOs;
using CeyloraAPI.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CeyloraAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class DestinationsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public DestinationsController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<DestinationDto>>> GetDestinations([FromQuery] string? region, [FromQuery] string? category, [FromQuery] string? search)
        {
            var query = _context.Destinations.AsQueryable();

            if (!string.IsNullOrWhiteSpace(region))
                query = query.Where(d => d.Region.ToLower() == region.ToLower());

            if (!string.IsNullOrWhiteSpace(category))
                query = query.Where(d => d.Category != null && d.Category.ToLower() == category.ToLower());

            if (!string.IsNullOrWhiteSpace(search))
                query = query.Where(d => d.Name.ToLower().Contains(search.ToLower()) || (d.Description != null && d.Description.ToLower().Contains(search.ToLower())));

            var destinations = await query.Select(d => new DestinationDto
            {
                Id = d.Id,
                Name = d.Name,
                Region = d.Region,
                Description = d.Description,
                Category = d.Category,
                Latitude = d.Latitude,
                Longitude = d.Longitude,
                ImageUrl = d.ImageUrl
            }).ToListAsync();

            return Ok(destinations);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<DestinationDto>> GetDestination(int id)
        {
            var d = await _context.Destinations.FindAsync(id);
            if (d == null) return NotFound(new { message = "Destination not found." });

            return Ok(new DestinationDto
            {
                Id = d.Id,
                Name = d.Name,
                Region = d.Region,
                Description = d.Description,
                Category = d.Category,
                Latitude = d.Latitude,
                Longitude = d.Longitude,
                ImageUrl = d.ImageUrl
            });
        }

        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<DestinationDto>> CreateDestination(CreateDestinationDto dto)
        {
            var destination = new Destination
            {
                Name = dto.Name,
                Region = dto.Region,
                Description = dto.Description,
                Category = dto.Category,
                Latitude = dto.Latitude,
                Longitude = dto.Longitude,
                ImageUrl = dto.ImageUrl,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Destinations.Add(destination);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetDestination), new { id = destination.Id }, new DestinationDto
            {
                Id = destination.Id,
                Name = destination.Name,
                Region = destination.Region,
                Description = destination.Description,
                Category = destination.Category,
                Latitude = destination.Latitude,
                Longitude = destination.Longitude,
                ImageUrl = destination.ImageUrl
            });
        }

        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> UpdateDestination(int id, CreateDestinationDto dto)
        {
            var destination = await _context.Destinations.FindAsync(id);
            if (destination == null) return NotFound(new { message = "Destination not found." });

            destination.Name = dto.Name;
            destination.Region = dto.Region;
            destination.Description = dto.Description;
            destination.Category = dto.Category;
            destination.Latitude = dto.Latitude;
            destination.Longitude = dto.Longitude;
            destination.ImageUrl = dto.ImageUrl;
            destination.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            return NoContent();
        }

        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> DeleteDestination(int id)
        {
            var destination = await _context.Destinations.FindAsync(id);
            if (destination == null) return NotFound(new { message = "Destination not found." });

            _context.Destinations.Remove(destination);
            await _context.SaveChangesAsync();
            return NoContent();
        }
    }
}
