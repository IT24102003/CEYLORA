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
    [Authorize]
    public class PaymentsController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IEmailService _emailService;
        private readonly INotificationService _notificationService;

        public PaymentsController(AppDbContext context, IEmailService emailService, INotificationService notificationService)
        {
            _context = context;
            _emailService = emailService;
            _notificationService = notificationService;
        }

        // GET: api/payments/booking/5
        [HttpGet("booking/{bookingId}")]
        public async Task<ActionResult<List<Payment>>> GetByBooking(int bookingId)
        {
            var payments = await _context.Payments.Where(p => p.BookingId == bookingId).ToListAsync();
            return Ok(payments);
        }

        // POST: api/payments (sandbox — validates amount against booking total)
        [HttpPost]
        public async Task<ActionResult<Payment>> Create(CreatePaymentDto dto)
        {
            var booking = await _context.Bookings.FindAsync(dto.BookingId);
            if (booking == null) return NotFound(new { message = "Booking not found." });

            if (dto.Amount != booking.TotalPrice)
                return BadRequest(new
                {
                    message = $"Payment amount ({dto.Amount}) does not match booking total ({booking.TotalPrice})."
                });

            var payment = new Payment
            {
                BookingId = dto.BookingId,
                Amount = dto.Amount,
                Status = PaymentStatus.Success,
                Provider = "Sandbox",
                CreatedAt = DateTime.UtcNow
            };

            _context.Payments.Add(payment);

            // 🔥 Payment no longer force-confirms the booking. For a package purchase, the
            // trip still needs the admin to assign a guide/vehicle (gated on IsPaid — see
            // AssignmentsController.AssignAndConfirm) before it becomes Confirmed. For an
            // AI-planned trip, the booking is ALREADY Confirmed by the time payment happens
            // (that flow pays after admin approval), so this just marks it paid either way.
            booking.IsPaid = true;
            booking.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            var tourist = await _context.Users.FindAsync(booking.TouristId);
            if (tourist != null)
            {
                _ = _emailService.SendPaymentConfirmationEmailAsync(
                    tourist.Email, tourist.Name, booking.Id, payment.Amount);
                await _notificationService.CreateAsync(
                    tourist.Id, "Payment Confirmed", $"We received your payment of LKR {payment.Amount} for booking #{booking.Id}.", NotificationType.PaymentConfirmed);
            }

            return CreatedAtAction(nameof(GetByBooking), new { bookingId = dto.BookingId }, payment);
        }
    }
}