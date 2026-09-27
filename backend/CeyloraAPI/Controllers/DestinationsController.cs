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

        // GET: api/destinations?region=Kandy&category=Nature&search=temple&page=1&pageSize=10&sortBy=name
        [HttpGet]
        public async Task<ActionResult<PagedResultDto<Destination>>> GetAll(
            [FromQuery] string? region,
            [FromQuery] string? category,
            [FromQuery] string? search,
            [FromQuery] string? sortBy = "name",
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            var query = _context.Destinations.AsQueryable();

            if (!string.IsNullOrWhiteSpace(region))
                query = query.Where(d => d.Region.ToLower() == region.ToLower());

            if (!string.IsNullOrWhiteSpace(category))
                query = query.Where(d => d.Category != null && d.Category.ToLower() == category.ToLower());

            if (!string.IsNullOrWhiteSpace(search))
                query = query.Where(d => d.Name.ToLower().Contains(search.ToLower())
                                       || (d.Description != null && d.Description.ToLower().Contains(search.ToLower())));

            query = sortBy?.ToLower() switch
            {
                "region" => query.OrderBy(d => d.Region),
                "newest" => query.OrderByDescending(d => d.CreatedAt),
                _ => query.OrderBy(d => d.Name)
            };

            var totalCount = await query.CountAsync();

            var items = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            return Ok(new PagedResultDto<Destination>
            {
                Items = items,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        // GET: api/destinations/5
        [HttpGet("{id}")]
        public async Task<ActionResult<Destination>> GetById(int id)
        {
            var destination = await _context.Destinations.FindAsync(id);
            if (destination == null) return NotFound(new { message = "Destination not found." });
            return Ok(destination);
        }

        // POST: api/destinations (Admin only)
        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<Destination>> Create(DestinationDto dto)
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

            return CreatedAtAction(nameof(GetById), new { id = destination.Id }, destination);
        }

        // PUT: api/destinations/5 (Admin only)
        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(int id, DestinationDto dto)
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

        // DELETE: api/destinations/5 (Admin only)
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var destination = await _context.Destinations.FindAsync(id);
            if (destination == null) return NotFound(new { message = "Destination not found." });

            _context.Destinations.Remove(destination);
            await _context.SaveChangesAsync();
            return NoContent();
        }
    }
}