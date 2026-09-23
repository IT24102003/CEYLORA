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
    public class HotelsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public HotelsController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<HotelDto>>> GetHotels([FromQuery] string? region, [FromQuery] int? minStars, [FromQuery] decimal? maxPrice)
        {
            var query = _context.Hotels
                .Include(h => h.Images)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(region))
                query = query.Where(h => h.Region.ToLower() == region.ToLower());

            if (minStars.HasValue)
                query = query.Where(h => h.StarRating >= minStars.Value);

            if (maxPrice.HasValue)
                query = query.Where(h => h.PricePerNight <= maxPrice.Value);

            var hotels = await query.Select(h => new HotelDto
            {
                Id = h.Id,
                Name = h.Name,
                Region = h.Region,
                Address = h.Address,
                StarRating = h.StarRating,
                PricePerNight = h.PricePerNight,
                RoomsAvailable = h.RoomsAvailable,
                Description = h.Description,
                ImageUrl = h.ImageUrl,
                Images = h.Images.Select(img => new HotelImageDto
                {
                    Id = img.Id,
                    ImageUrl = img.ImageUrl,
                    IsCover = img.IsCover
                }).ToList()
            }).ToListAsync();

            return Ok(hotels);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<HotelDto>> GetHotel(int id)
        {
            var h = await _context.Hotels
                .Include(h => h.Images)
                .FirstOrDefaultAsync(h => h.Id == id);

            if (h == null) return NotFound(new { message = "Hotel not found." });

            return Ok(new HotelDto
            {
                Id = h.Id,
                Name = h.Name,
                Region = h.Region,
                Address = h.Address,
                StarRating = h.StarRating,
                PricePerNight = h.PricePerNight,
                RoomsAvailable = h.RoomsAvailable,
                Description = h.Description,
                ImageUrl = h.ImageUrl,
                Images = h.Images.Select(img => new HotelImageDto
                {
                    Id = img.Id,
                    ImageUrl = img.ImageUrl,
                    IsCover = img.IsCover
                }).ToList()
            });
        }

        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<HotelDto>> CreateHotel(CreateHotelDto dto)
        {
            var hotel = new Hotel
            {
                Name = dto.Name,
                Region = dto.Region,
                Address = dto.Address,
                StarRating = dto.StarRating,
                PricePerNight = dto.PricePerNight,
                RoomsAvailable = dto.RoomsAvailable,
                Description = dto.Description,
                ImageUrl = dto.ImageUrl,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Hotels.Add(hotel);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetHotel), new { id = hotel.Id }, new HotelDto
            {
                Id = hotel.Id,
                Name = hotel.Name,
                Region = hotel.Region,
                Address = hotel.Address,
                StarRating = hotel.StarRating,
                PricePerNight = hotel.PricePerNight,
                RoomsAvailable = hotel.RoomsAvailable,
                Description = hotel.Description,
                ImageUrl = hotel.ImageUrl
            });
        }
    }
}
