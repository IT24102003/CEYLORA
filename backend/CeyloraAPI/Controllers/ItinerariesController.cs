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
    [Authorize]
    public class ItinerariesController : ControllerBase
    {
        private readonly AppDbContext _context;

        public ItinerariesController(AppDbContext context)
        {
            _context = context;
        }

        // GET: api/itineraries/booking/5
        [HttpGet("booking/{bookingId}")]
        public async Task<ActionResult<Itinerary>> GetByBooking(int bookingId)
        {
            var itinerary = await _context.Itineraries
                .Include(i => i.Days)
                .FirstOrDefaultAsync(i => i.BookingId == bookingId);

            if (itinerary == null) return NotFound(new { message = "Itinerary not found." });
            return Ok(itinerary);
        }

        // GET: api/itineraries/pending-approval (Admin monitor queue)
        [HttpGet("pending-approval")]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<List<Itinerary>>> GetPendingApproval()
        {
            var pending = await _context.Itineraries
                .Include(i => i.Days)
                .Include(i => i.Booking)
                .Where(i => i.ApprovalStatus == ApprovalStatus.PendingApproval)
                .ToListAsync();

            return Ok(pending);
        }

        // POST: api/itineraries
        [HttpPost]
        public async Task<ActionResult<Itinerary>> Create(CreateItineraryDto dto)
        {
            var booking = await _context.Bookings.FindAsync(dto.BookingId);
            if (booking == null) return NotFound(new { message = "Booking not found." });

            var itinerary = new Itinerary
            {
                BookingId = dto.BookingId,
                GeneratedBy = dto.GeneratedBy,
                ApprovalStatus = ApprovalStatus.PendingApproval,
                CreatedAt = DateTime.UtcNow,
                Days = dto.Days.Select(d => new ItineraryDay
                {
                    DayNumber = d.DayNumber,
                    ActivitiesJson = d.ActivitiesJson,
                    Notes = d.Notes
                }).ToList()
            };

            _context.Itineraries.Add(itinerary);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetByBooking), new { bookingId = dto.BookingId }, itinerary);
        }

        // PUT: api/itineraries/5/approval (Admin approves/rejects/requests revision)
        [HttpPut("{id}/approval")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> UpdateApproval(int id, UpdateApprovalStatusDto dto)
        {
            var itinerary = await _context.Itineraries.FindAsync(id);
            if (itinerary == null) return NotFound(new { message = "Itinerary not found." });

            if (!Enum.TryParse<ApprovalStatus>(dto.ApprovalStatus, true, out var newStatus))
                return BadRequest(new { message = "Invalid approval status." });

            itinerary.ApprovalStatus = newStatus;
            await _context.SaveChangesAsync();

            // If approved, auto-confirm the booking
            if (newStatus == ApprovalStatus.Approved)
            {
                var booking = await _context.Bookings.FindAsync(itinerary.BookingId);
                if (booking != null)
                {
                    booking.Status = BookingStatus.Confirmed;
                    booking.UpdatedAt = DateTime.UtcNow;
                    await _context.SaveChangesAsync();
                }
            }

            return NoContent();
        }
    }
}