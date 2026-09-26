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
                CreatedAt = DateTime.UtcNow 
            }; 
  
            _context.Reviews.Add(review); 
            await _context.SaveChangesAsync(); 
  
            // 🔥 BUSINESS-SPECIFIC OPERATION: Weighted rating recalculation for the assigned guide 
            var assignment = await _context.Assignments 
                .FirstOrDefaultAsync(a => a.BookingId == dto.BookingId && a.GuideId != null); 
  
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