using CeyloraAPI.Data;
using CeyloraAPI.DTOs;
using CeyloraAPI.Models;
using CeyloraAPI.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace CeyloraAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class BookingsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public BookingsController(AppDbContext context)
        {
            _context = context;
        }

        // GET: api/bookings?status=Pending&page=1&pageSize=10
        // Admin sees all; Tourist sees only their own
        [HttpGet]
        public async Task<ActionResult<PagedResultDto<Booking>>> GetAll(
            [FromQuery] string? status,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            var query = _context.Bookings.Include(b => b.Package).AsQueryable();

            var role = User.FindFirstValue(ClaimTypes.Role);
            var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

            if (role != "Admin")
                query = query.Where(b => b.TouristId == userId);

            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<BookingStatus>(status, true, out var statusEnum))
                query = query.Where(b => b.Status == statusEnum);

            var totalCount = await query.CountAsync();
            var items = await query
                .OrderByDescending(b => b.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            return Ok(new PagedResultDto<Booking>
            {
                Items = items,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        // GET: api/bookings/5
        [HttpGet("{id}")]
        public async Task<ActionResult<Booking>> GetById(int id)
        {
            var booking = await _context.Bookings
                .Include(b => b.Package)
                .FirstOrDefaultAsync(b => b.Id == id);

            if (booking == null) return NotFound(new { message = "Booking not found." });
            return Ok(booking);
        }

        // POST: api/bookings (Tourist creates a booking)
        [HttpPost]
        public async Task<ActionResult<Booking>> Create(CreateBookingDto dto)
        {
            var package = await _context.Packages.FindAsync(dto.PackageId);
            if (package == null) return NotFound(new { message = "Package not found." });

            var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

            var booking = new Booking
            {
                TouristId = userId,
                PackageId = dto.PackageId,
                Status = BookingStatus.Pending,
                TotalPrice = package.BasePrice * dto.GroupSize, // simplified; use PricingService for full logic
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Bookings.Add(booking);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetById), new { id = booking.Id }, booking);
        }

        // PUT: api/bookings/5/status (Admin only — confirm/cancel/complete)
        [HttpPut("{id}/status")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> UpdateStatus(int id, UpdateBookingStatusDto dto)
        {
            var booking = await _context.Bookings.FindAsync(id);
            if (booking == null) return NotFound(new { message = "Booking not found." });

            if (!Enum.TryParse<BookingStatus>(dto.Status, true, out var newStatus))
                return BadRequest(new { message = "Invalid status value." });

            booking.Status = newStatus;
            booking.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();
            return NoContent();
        }

        // DELETE: api/bookings/5 (Admin only)
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var booking = await _context.Bookings.FindAsync(id);
            if (booking == null) return NotFound(new { message = "Booking not found." });

            _context.Bookings.Remove(booking);
            await _context.SaveChangesAsync();
            return NoContent();
        }
    }
}