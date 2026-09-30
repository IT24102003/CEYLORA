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
        private readonly IEmailService _emailService;
        private readonly INotificationService _notificationService;

        public BookingsController(AppDbContext context, IEmailService emailService, INotificationService notificationService)
        {
            _context = context;
            _emailService = emailService;
            _notificationService = notificationService;
        }

        // GET: api/bookings?status=Pending&page=1&pageSize=10
        // For Admin: enriched with tourist details + the assigned guide/vehicle (if any),
        // so the admin panel's Bookings tab can show everything in one table.
        [HttpGet]
        public async Task<IActionResult> GetAll(
            [FromQuery] string? status,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            var query = _context.Bookings.Include(b => b.Package).Include(b => b.Tourist).AsQueryable();

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

            var bookingIds = items.Select(b => b.Id).ToList();
            var assignments = await _context.Assignments
                .Include(a => a.Guide).ThenInclude(g => g!.User)
                .Include(a => a.Vehicle)
                .Where(a => bookingIds.Contains(a.BookingId) && a.Status != AssignmentStatus.Cancelled)
                .ToListAsync();

            var projected = items.Select(b =>
            {
                var assignment = assignments.FirstOrDefault(a => a.BookingId == b.Id);
                return new
                {
                    b.Id,
                    b.TouristId,
                    b.PackageId,
                    packageName = b.Package?.Name ?? b.CustomTripName ?? b.CustomTripObjective,
                    // Kept as a nested object too, for mobile screens (profile_screen.dart)
                    // that read b["package"]?["name"] instead of the flat packageName string.
                    package = b.Package == null ? null : new { b.Package.Id, b.Package.Name },
                    b.Status,
                    b.IsPaid,
                    b.GroupSize,
                    b.TotalPrice,
                    b.PlannedStartDate,
                    b.CreatedAt,
                    tourist = b.Tourist == null ? null : new
                    {
                        b.Tourist.Id,
                        b.Tourist.Name,
                        b.Tourist.Email,
                        b.Tourist.MobileNumber
                    },
                    guideName = assignment?.Guide?.User?.Name,
                    vehicleName = assignment?.Vehicle != null ? (assignment.Vehicle.Name ?? assignment.Vehicle.Type) : null
                };
            });

            return Ok(new
            {
                items = projected,
                totalCount,
                page,
                pageSize
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

        // GET: api/bookings/5/details — the "tap a booking, see everything" screen, used by
        // the Tourist (their own booking), the assigned Guide, the assigned Vehicle's Owner,
        // and the Admin. Bundles the tourist, the full package (destinations & hotels) or the
        // custom AI-trip objective, the assigned guide & vehicle, and payment/assignment status.
        [HttpGet("{id}/details")]
        public async Task<IActionResult> GetDetails(int id)
        {
            var booking = await _context.Bookings
                .Include(b => b.Tourist)
                .Include(b => b.Package).ThenInclude(p => p!.PackageDestinations).ThenInclude(pd => pd.Destination)
                .Include(b => b.Package).ThenInclude(p => p!.PackageHotels).ThenInclude(ph => ph.Hotel)
                .FirstOrDefaultAsync(b => b.Id == id);
            if (booking == null) return NotFound(new { message = "Booking not found." });

            var assignment = await _context.Assignments
                .Include(a => a.Guide).ThenInclude(g => g!.User)
                .Include(a => a.Vehicle).ThenInclude(v => v!.Operator)
                .FirstOrDefaultAsync(a => a.BookingId == id && a.Status != AssignmentStatus.Cancelled);

            var role = User.FindFirstValue(ClaimTypes.Role);
            var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            var isOwner = booking.TouristId == userId;
            var isAssignedGuide = assignment?.Guide?.UserId == userId;
            var isAssignedVehicleOwner = assignment?.Vehicle?.OperatorId == userId;
            if (role != "Admin" && !isOwner && !isAssignedGuide && !isAssignedVehicleOwner)
                return Forbid();

            return Ok(new
            {
                booking.Id,
                booking.Status,
                booking.IsPaid,
                booking.GroupSize,
                booking.TotalPrice,
                booking.PlannedStartDate,
                booking.TripStartedAt,
                booking.CreatedAt,
                tripName = booking.Package?.Name ?? booking.CustomTripName ?? booking.CustomTripObjective ?? "Trip",
                tourist = new
                {
                    booking.Tourist.Id,
                    booking.Tourist.Name,
                    booking.Tourist.Email,
                    booking.Tourist.MobileNumber
                },
                package = booking.Package == null ? null : new
                {
                    booking.Package.Id,
                    booking.Package.Name,
                    booking.Package.Description,
                    booking.Package.BasePrice,
                    booking.Package.DurationDays,
                    booking.Package.MaxPeople,
                    destinations = booking.Package.PackageDestinations
                        .OrderBy(pd => pd.DayNumber)
                        .Select(pd => new { pd.DayNumber, name = pd.Destination.Name, region = pd.Destination.Region, pd.Destination.Latitude, pd.Destination.Longitude }),
                    hotels = booking.Package.PackageHotels.Select(ph => new { ph.Hotel.Name, ph.Hotel.Region, ph.Hotel.PricePerNight })
                },
                customTrip = booking.Package != null ? null : new
                {
                    objective = booking.CustomTripObjective,
                    durationDays = booking.CustomTripDurationDays
                },
                guide = assignment?.Guide == null ? null : new
                {
                    assignment.Guide.Id,
                    name = assignment.Guide.User?.Name,
                    mobileNumber = assignment.Guide.User?.MobileNumber,
                    assignment.Guide.Region,
                    assignment.Guide.Rating
                },
                vehicle = assignment?.Vehicle == null ? null : new
                {
                    assignment.Vehicle.Id,
                    name = assignment.Vehicle.Name ?? assignment.Vehicle.Type,
                    assignment.Vehicle.Type,
                    assignment.Vehicle.Capacity,
                    assignment.Vehicle.PricePerKm,
                    ownerName = assignment.Vehicle.Operator?.Name,
                    ownerPhone = assignment.Vehicle.Operator?.MobileNumber
                }
            });
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
                GroupSize = dto.GroupSize > 0 ? dto.GroupSize : 1,
                PlannedStartDate = dto.TravelDate,
                TotalPrice = package.BasePrice * dto.GroupSize,
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

            if (newStatus == BookingStatus.Confirmed)
            {
                var tourist = await _context.Users.FindAsync(booking.TouristId);
                if (tourist != null)
                {
                    _ = _emailService.SendBookingApprovedEmailAsync(tourist.Email, tourist.Name, booking.Id);
                    await _notificationService.CreateAsync(
                        tourist.Id, "Booking Approved", $"Your booking #{booking.Id} has been approved!", NotificationType.BookingApproved);
                }
            }
            else if (newStatus == BookingStatus.OnGoing)
            {
                await _notificationService.CreateAsync(
                    booking.TouristId, "Trip Started", $"Your trip (booking #{booking.Id}) is now on going. Have a great trip!", NotificationType.General);
            }
            else if (newStatus == BookingStatus.Ended)
            {
                await _notificationService.CreateAsync(
                    booking.TouristId, "Trip Ended", $"Your trip (booking #{booking.Id}) has ended. We hope you enjoyed it!", NotificationType.General);
            }
            else if (newStatus == BookingStatus.Rejected)
            {
                await _notificationService.CreateAsync(
                    booking.TouristId, "Trip Rejected", $"Your trip (booking #{booking.Id}) was rejected by the admin.", NotificationType.BookingCancelled);
            }

            return NoContent();
        }

        // PUT: api/bookings/5/cancel (Tourist cancels their own booking)
        [HttpPut("{id}/cancel")]
        public async Task<IActionResult> Cancel(int id)
        {
            var booking = await _context.Bookings.FindAsync(id);
            if (booking == null) return NotFound(new { message = "Booking not found." });

            var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            var role = User.FindFirstValue(ClaimTypes.Role);

            if (role != "Admin" && booking.TouristId != userId)
                return Forbid();

            if (booking.Status == BookingStatus.Cancelled || booking.Status == BookingStatus.Rejected)
                return BadRequest(new { message = "Booking is already cancelled/rejected." });

            if (booking.Status == BookingStatus.Ended)
                return BadRequest(new { message = "A completed trip can't be cancelled." });

            booking.Status = BookingStatus.Cancelled;
            booking.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            await _notificationService.CreateAsync(
                booking.TouristId, "Booking Cancelled", $"Booking #{booking.Id} has been cancelled.", NotificationType.BookingCancelled);

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