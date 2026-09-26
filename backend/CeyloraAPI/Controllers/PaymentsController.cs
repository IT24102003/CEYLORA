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
    public class PaymentsController : ControllerBase 
    { 
        private readonly AppDbContext _context; 
  
        public PaymentsController(AppDbContext context) 
        { 
            _context = context; 
        } 
  
        // GET: api/payments/booking/5 
        [HttpGet("booking/{bookingId}")] 
        public async Task<ActionResult<List<Payment>>> GetByBooking(int bookingId) 
        { 
            var payments = await _context.Payments.Where(p => p.BookingId == 
bookingId).ToListAsync(); 
            return Ok(payments); 
        } 
  
        // POST: api/payments (sandbox — validates amount against booking total) 
        [HttpPost] 
        public async Task<ActionResult<Payment>> Create(CreatePaymentDto dto) 
        { 
            var booking = await _context.Bookings.FindAsync(dto.BookingId); 
            if (booking == null) return NotFound(new { message = "Booking not found." }); 
  
            // 🔥 Business-rule validation: amount must match the booking total 
            if (dto.Amount != booking.TotalPrice) 
                return BadRequest(new 
                { 
                    message = $"Payment amount ({dto.Amount}) does not match booking total ({booking.TotalPrice})." 
                }); 
  
            var payment = new Payment 
            { 
BookingId = dto.BookingId, 
Amount = dto.Amount, 
Status = PaymentStatus.Success, // sandbox: always succeeds once validated 
Provider = "Sandbox", 
CreatedAt = DateTime.UtcNow 
}; 
_context.Payments.Add(payment); 
booking.Status = BookingStatus.Confirmed; 
booking.UpdatedAt = DateTime.UtcNow; 
await _context.SaveChangesAsync(); 
return CreatedAtAction(nameof(GetByBooking), new { bookingId = dto.BookingId },payment); 
        } 
    } 
} 
