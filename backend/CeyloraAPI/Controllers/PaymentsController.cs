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

        // GET: api/payments?status=Success&search=john&page=1&pageSize=20 (Admin only)
        // 🔥 New — powers the admin panel's "Payments" tab. The only payments endpoint that
        // existed before was scoped to a single booking, with no way to see payments
        // across the whole platform. Projects straight to a flat DTO (rather than returning
        // the Payment entity with its Booking/Tourist navigation included) to avoid a
        // circular-reference serialization error.
        [HttpGet]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetAll(
            [FromQuery] string? status,
            [FromQuery] string? search,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20)
        {
            var query = _context.Payments
                .Include(p => p.Booking)
                .ThenInclude(b => b.Tourist)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<PaymentStatus>(status, true, out var statusEnum))
                query = query.Where(p => p.Status == statusEnum);

            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.ToLower();
                query = query.Where(p =>
                    p.Booking.Tourist.Name.ToLower().Contains(s) ||
                    p.Booking.Tourist.Email.ToLower().Contains(s) ||
                    p.BookingId.ToString() == s);
            }

            query = query.OrderByDescending(p => p.CreatedAt);

            var totalCount = await query.CountAsync();
            var items = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(p => new
                {
                    id = p.Id,
                    bookingId = p.BookingId,
                    touristName = p.Booking.Tourist.Name,
                    touristEmail = p.Booking.Tourist.Email,
                    tripName = p.Booking.CustomTripName ?? (p.Booking.Package != null ? p.Booking.Package.Name : null),
                    amount = p.Amount,
                    status = p.Status.ToString(),
                    provider = p.Provider,
                    createdAt = p.CreatedAt
                })
                .ToListAsync();

            var totalRevenue = await _context.Payments
                .Where(p => p.Status == PaymentStatus.Success)
                .SumAsync(p => (decimal?)p.Amount) ?? 0;

            return Ok(new
            {
                items,
                totalCount,
                page,
                pageSize,
                totalRevenue
            });
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