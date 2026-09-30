using CeyloraAPI.Data;
using CeyloraAPI.DTOs;
using CeyloraAPI.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace CeyloraAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ReviewsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public ReviewsController(AppDbContext context)
        {
            _context = context;
        }

        // GET: api/reviews/booking/5 
        [HttpGet("booking/{bookingId}")]
        public async Task<ActionResult<List<Review>>> GetByBooking(int bookingId)
        {
            var reviews = await _context.Reviews.Where(r => r.BookingId ==
bookingId).ToListAsync();
            return Ok(reviews);
        }

        // POST: api/reviews (Tourist submits after trip completion) 
        [HttpPost]
        [Authorize]
        public async Task<ActionResult<Review>> Create(CreateReviewDto dto)
        {
            if (dto.Rating < 1 || dto.Rating > 5)
                return BadRequest(new { message = "Rating must be between 1 and 5." });

            var booking = await _context.Bookings.FindAsync(dto.BookingId);
            if (booking == null) return NotFound(new { message = "Booking not found." });

            var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

            var review = new Review
            {
                BookingId = dto.BookingId,
                TouristId = userId,
                Rating = dto.Rating,
                Comment = dto.Comment,
                HotelRating = dto.HotelRating,
                VehicleRating = dto.VehicleRating,
                CreatedAt = DateTime.UtcNow
            };

            _context.Reviews.Add(review);
            await _context.SaveChangesAsync();

            // 🔥 BUSINESS-SPECIFIC OPERATION: Weighted rating recalculation for the assigned guide
            var assignment = await _context.Assignments
                .FirstOrDefaultAsync(a => a.BookingId == dto.BookingId);

            if (assignment?.GuideId != null)
            {
                var guide = await _context.Guides.FindAsync(assignment.GuideId.Value);
                if (guide != null)
                {
                    var guideBookingIds = await _context.Assignments
                        .Where(a => a.GuideId == guide.Id)
                        .Select(a => a.BookingId)
                        .ToListAsync();

                    var allRatings = await _context.Reviews
                        .Where(r => guideBookingIds.Contains(r.BookingId))
                        .Select(r => r.Rating)
                        .ToListAsync();

                    if (allRatings.Count > 0)
                    {
                        guide.Rating = Math.Round(allRatings.Average(), 2);
                        await _context.SaveChangesAsync();
                    }
                }
            }

            // 🔥 BUSINESS-SPECIFIC OPERATION: Weighted rating recalculation for the hotel used on this trip
            if (dto.HotelRating.HasValue)
            {
                var hotelBooking = await _context.HotelBookings
                    .FirstOrDefaultAsync(hb => hb.BookingId == dto.BookingId);

                if (hotelBooking != null)
                {
                    var hotel = await _context.Hotels.FindAsync(hotelBooking.HotelId);
                    if (hotel != null)
                    {
                        var hotelBookingIds = await _context.HotelBookings
                            .Where(hb => hb.HotelId == hotel.Id)
                            .Select(hb => hb.BookingId)
                            .ToListAsync();

                        var hotelRatings = await _context.Reviews
                            .Where(r => hotelBookingIds.Contains(r.BookingId) && r.HotelRating != null)
                            .Select(r => r.HotelRating!.Value)
                            .ToListAsync();

                        if (hotelRatings.Count > 0)
                        {
                            hotel.Rating = Math.Round(hotelRatings.Average(), 2);
                            await _context.SaveChangesAsync();
                        }
                    }
                }
            }

            // 🔥 BUSINESS-SPECIFIC OPERATION: Weighted rating recalculation for the vehicle used on this trip
            if (dto.VehicleRating.HasValue && assignment?.VehicleId != null)
            {
                var vehicle = await _context.Vehicles.FindAsync(assignment.VehicleId.Value);
                if (vehicle != null)
                {
                    var vehicleBookingIds = await _context.Assignments
                        .Where(a => a.VehicleId == vehicle.Id)
                        .Select(a => a.BookingId)
                        .ToListAsync();

                    var vehicleRatings = await _context.Reviews
                        .Where(r => vehicleBookingIds.Contains(r.BookingId) && r.VehicleRating != null)
                        .Select(r => r.VehicleRating!.Value)
                        .ToListAsync();

                    if (vehicleRatings.Count > 0)
                    {
                        vehicle.Rating = Math.Round(vehicleRatings.Average(), 2);
                        await _context.SaveChangesAsync();
                    }
                }
            }

            return CreatedAtAction(nameof(GetByBooking), new { bookingId = dto.BookingId },
review);
        }

        // DELETE: api/reviews/5 (Admin moderation) 
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var review = await _context.Reviews.FindAsync(id);
            if (review == null) return NotFound(new { message = "Review not found." });

            _context.Reviews.Remove(review);
            await _context.SaveChangesAsync();
            return NoContent();
        }
    }
}