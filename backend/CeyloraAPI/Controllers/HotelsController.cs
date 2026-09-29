using CeyloraAPI.Data;
using CeyloraAPI.DTOs;
using CeyloraAPI.Models;
using CeyloraAPI.Services;
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
        private readonly IHotelService _hotelService;

        public HotelsController(AppDbContext context, IHotelService hotelService)
        {
            _context = context;
            _hotelService = hotelService;
        }

        // GET: api/hotels?region=Kandy&minStars=3&page=1&pageSize=10
        [HttpGet]
        public async Task<ActionResult<PagedResultDto<Hotel>>> GetAll(
            [FromQuery] string? region,
            [FromQuery] int? minStars,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            var query = _context.Hotels.Include(h => h.Images).AsQueryable();

            if (!string.IsNullOrWhiteSpace(region))
                query = query.Where(h => h.Region.ToLower() == region.ToLower());

            if (minStars.HasValue)
                query = query.Where(h => h.StarRating >= minStars.Value);

            var totalCount = await query.CountAsync();
            var items = await query
                .OrderByDescending(h => h.StarRating)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            return Ok(new PagedResultDto<Hotel>
            {
                Items = items,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        // GET: api/hotels/5
        [HttpGet("{id}")]
        public async Task<ActionResult<Hotel>> GetById(int id)
        {
            var hotel = await _context.Hotels.Include(h => h.Images).FirstOrDefaultAsync(h => h.Id == id);
            if (hotel == null) return NotFound(new { message = "Hotel not found." });
            return Ok(hotel);
        }

        // POST: api/hotels (Admin only)
        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<Hotel>> Create(HotelDto dto)
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

            return CreatedAtAction(nameof(GetById), new { id = hotel.Id }, hotel);
        }

        // PUT: api/hotels/5 (Admin only)
        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(int id, HotelDto dto)
        {
            var hotel = await _context.Hotels.FindAsync(id);
            if (hotel == null) return NotFound(new { message = "Hotel not found." });

            hotel.Name = dto.Name;
            hotel.Region = dto.Region;
            hotel.Address = dto.Address;
            hotel.StarRating = dto.StarRating;
            hotel.PricePerNight = dto.PricePerNight;
            hotel.RoomsAvailable = dto.RoomsAvailable;
            hotel.Description = dto.Description;
            hotel.ImageUrl = dto.ImageUrl;
            hotel.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            return NoContent();
        }

        // DELETE: api/hotels/5 (Admin only)
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var hotel = await _context.Hotels.FindAsync(id);
            if (hotel == null) return NotFound(new { message = "Hotel not found." });

            _context.Hotels.Remove(hotel);
            await _context.SaveChangesAsync();
            return NoContent();
        }

        // 🔥 BUSINESS-SPECIFIC OPERATION: Availability Check
        // POST: api/hotels/5/check-availability
        [HttpPost("{id}/check-availability")]
        public async Task<ActionResult<AvailabilityCheckResponseDto>> CheckAvailability(int id, AvailabilityCheckRequestDto request)
        {
            var result = await _hotelService.CheckAvailabilityAsync(id, request.CheckIn, request.CheckOut, request.RoomsNeeded);
            return Ok(result);
        }

        // POST: api/hotels/5/images (Admin only) — add image URL to gallery
        [HttpPost("{id}/images")]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<HotelImage>> AddImage(int id, [FromBody] string imageUrl)
        {
            var hotel = await _context.Hotels.FindAsync(id);
            if (hotel == null) return NotFound(new { message = "Hotel not found." });

            var image = new HotelImage
            {
                HotelId = id,
                ImageUrl = imageUrl,
                IsCover = !await _context.HotelImages.AnyAsync(hi => hi.HotelId == id), // first image = cover
                UploadedAt = DateTime.UtcNow
            };

            _context.HotelImages.Add(image);
            await _context.SaveChangesAsync();

            return Ok(image);
        }  
    }
}