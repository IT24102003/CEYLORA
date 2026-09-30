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
    public class AssignmentsController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IAssignmentService _assignmentService;
        private readonly INotificationService _notificationService;

        public AssignmentsController(AppDbContext context, IAssignmentService assignmentService, INotificationService notificationService)
        {
            _context = context;
            _assignmentService = assignmentService;
            _notificationService = notificationService;
        }

        // GET: api/assignments/my — the logged-in Guide's assigned trips (active + upcoming)
        [HttpGet("my")]
        [Authorize(Roles = "Guide")]
        public async Task<IActionResult> GetMyAssignments()
        {
            var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            var guide = await _context.Guides.FirstOrDefaultAsync(g => g.UserId == userId);
            if (guide == null) return Ok(new List<object>());

            var assignments = await _context.Assignments
                .Where(a => a.GuideId == guide.Id && a.Status != AssignmentStatus.Cancelled)
                .Include(a => a.Booking).ThenInclude(b => b.Package)
                .Include(a => a.Vehicle)
                .OrderByDescending(a => a.AssignedAt)
                .ToListAsync();

            // Flat estimated fee per day the trip runs — same figure shown to the tourist
            // on the trip-review screen and used in the Guide earnings summary.
            const decimal guideFeePerDay = 2500m;

            var result = assignments.Select(a =>
            {
                var days = a.Booking.Package?.DurationDays ?? a.Booking.CustomTripDurationDays ?? 1;
                // The earliest date the guide is allowed to tap "End Trip" — the full
                // duration must have elapsed since TripStartedAt (start date counts as day 1).
                var earliestEndDate = a.Booking.TripStartedAt.HasValue
                    ? a.Booking.TripStartedAt.Value.Date.AddDays(days - 1)
                    : (DateTime?)null;
                return new
                {
                    assignmentId = a.Id,
                    bookingId = a.BookingId,
                    bookingStatus = a.Booking.Status.ToString(),
                    isPaid = a.Booking.IsPaid,
                    packageName = a.Booking.Package?.Name ?? a.Booking.CustomTripName ?? a.Booking.CustomTripObjective ?? "",
                    durationDays = days,
                    vehicleType = a.Vehicle != null ? a.Vehicle.Type : null,
                    vehicleName = a.Vehicle != null ? (a.Vehicle.Name ?? a.Vehicle.Type) : null,
                    assignedAt = a.AssignedAt,
                    tripStartedAt = a.Booking.TripStartedAt,
                    earliestEndDate = earliestEndDate?.ToString("yyyy-MM-dd"),
                    canEndTrip = earliestEndDate == null || DateTime.UtcNow.Date >= earliestEndDate,
                    estimatedEarning = guideFeePerDay * days
                };
            });

            return Ok(result);
        }

        // GET: api/assignments/my-vehicle — the logged-in Vehicle Owner's assigned trips (across all their vehicles)
        [HttpGet("my-vehicle")]
        [Authorize(Roles = "VehicleOwner")]
        public async Task<IActionResult> GetMyVehicleAssignments()
        {
            var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            var vehicleIds = await _context.Vehicles
                .Where(v => v.OperatorId == userId)
                .Select(v => v.Id)
                .ToListAsync();

            var assignments = await _context.Assignments
                .Where(a => a.VehicleId.HasValue && vehicleIds.Contains(a.VehicleId.Value) && a.Status != AssignmentStatus.Cancelled)
                .Include(a => a.Booking).ThenInclude(b => b.Package)
                .Include(a => a.Vehicle)
                .Include(a => a.Guide).ThenInclude(g => g!.User)
                .OrderByDescending(a => a.AssignedAt)
                .ToListAsync();

            var result = assignments.Select(a =>
            {
                var days = a.Booking.Package?.DurationDays ?? a.Booking.CustomTripDurationDays ?? 1;
                var pricePerKm = a.Vehicle?.PricePerKm ?? 0;
                return new
                {
                    assignmentId = a.Id,
                    bookingId = a.BookingId,
                    bookingStatus = a.Booking.Status.ToString(),
                    packageName = a.Booking.Package?.Name ?? a.Booking.CustomTripName ?? a.Booking.CustomTripObjective ?? "",
                    durationDays = days,
                    vehicleName = a.Vehicle != null ? (a.Vehicle.Name ?? a.Vehicle.Type) : null,
                    guideName = a.Guide != null && a.Guide.User != null ? a.Guide.User.Name : null,
                    assignedAt = a.AssignedAt,
                    // Estimated: per-km rate x assumed daily distance x trip duration.
                    estimatedEarning = pricePerKm * (decimal)VehiclePricing.AssumedKmPerDay * days
                };
            });

            return Ok(result);
        }

        // PUT: api/assignments/5/start — the assigned Guide starts the trip.
        // Moves the Booking's trip status to OnGoing (shown on Admin/Tourist/Guide/Vehicle
        // Owner sides). While OnGoing, the guide/vehicle stay IsAvailable=false so they can't
        // be picked for another trip, and their "Available" toggle is blocked (see
        // GuidesController/VehiclesController ToggleAvailability).
        [HttpPut("{id}/start")]
        [Authorize(Roles = "Guide")]
        public async Task<IActionResult> StartTrip(int id)
        {
            var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            var assignment = await _context.Assignments
                .Include(a => a.Booking)
                .Include(a => a.Guide)
                .FirstOrDefaultAsync(a => a.Id == id);
            if (assignment == null) return NotFound(new { message = "Assignment not found." });
            if (assignment.Guide == null || assignment.Guide.UserId != userId) return Forbid();

            if (assignment.Booking.Status != BookingStatus.Confirmed)
                return BadRequest(new { message = "Only a confirmed trip can be started." });

            // 🔥 For an AI-planned trip, the admin's approval already sets Status=Confirmed
            // BEFORE the tourist pays (payment happens afterward, from their Profile) — so
            // without this check the guide could start the trip before any payment exists.
            // (A package-purchase booking is already guaranteed paid by this point — see
            // AssignAndConfirm — so this is just a safety net for that flow too.)
            if (!assignment.Booking.IsPaid)
                return BadRequest(new { message = "The tourist hasn't completed payment for this trip yet." });

            assignment.Booking.Status = BookingStatus.OnGoing;
            assignment.Booking.TripStartedAt = DateTime.UtcNow;
            assignment.Booking.UpdatedAt = DateTime.UtcNow;
            assignment.Status = AssignmentStatus.InProgress;
            await _context.SaveChangesAsync();

            await _notificationService.CreateAsync(
                assignment.Booking.TouristId, "Trip Started", $"Your trip (booking #{assignment.BookingId}) is now on going.", NotificationType.General);
            if (assignment.VehicleId.HasValue)
            {
                var vehicle = await _context.Vehicles.FindAsync(assignment.VehicleId.Value);
                if (vehicle != null)
                {
                    await _notificationService.CreateAsync(
                        vehicle.OperatorId, "Trip Started", $"Booking #{assignment.BookingId} is now on going.", NotificationType.General);
                }
            }

            return NoContent();
        }

        // PUT: api/assignments/5/end — the assigned Guide ends the trip.
        // Moves the Booking to Ended and frees the guide/vehicle (IsAvailable=true again)
        // so they can be picked for a new trip.
        [HttpPut("{id}/end")]
        [Authorize(Roles = "Guide")]
        public async Task<IActionResult> EndTrip(int id)
        {
            var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            var assignment = await _context.Assignments
                .Include(a => a.Booking).ThenInclude(b => b.Package)
                .Include(a => a.Guide)
                .Include(a => a.Vehicle)
                .FirstOrDefaultAsync(a => a.Id == id);
            if (assignment == null) return NotFound(new { message = "Assignment not found." });
            if (assignment.Guide == null || assignment.Guide.UserId != userId) return Forbid();

            if (assignment.Booking.Status != BookingStatus.OnGoing)
                return BadRequest(new { message = "Only a trip that is on going can be ended." });

            // 🔥 Guide can only end the trip once its full duration has elapsed since it was
            // started — e.g. a 2-day trip started on 2026-09-30 can only be ended on/after
            // 2026-10-01 (start date counts as day 1).
            var durationDays = assignment.Booking.Package?.DurationDays ?? assignment.Booking.CustomTripDurationDays ?? 1;
            if (assignment.Booking.TripStartedAt.HasValue)
            {
                var earliestEndDate = assignment.Booking.TripStartedAt.Value.Date.AddDays(durationDays - 1);
                if (DateTime.UtcNow.Date < earliestEndDate)
                {
                    return BadRequest(new
                    {
                        message = $"This is a {durationDays}-day trip — you can only end it on or after {earliestEndDate:yyyy-MM-dd}.",
                        earliestEndDate = earliestEndDate.ToString("yyyy-MM-dd")
                    });
                }
            }

            assignment.Booking.Status = BookingStatus.Ended;
            assignment.Booking.UpdatedAt = DateTime.UtcNow;
            assignment.Status = AssignmentStatus.Completed;

            assignment.Guide.IsAvailable = true;
            if (assignment.Vehicle != null) assignment.Vehicle.IsAvailable = true;

            await _context.SaveChangesAsync();

            await _notificationService.CreateAsync(
                assignment.Booking.TouristId, "Trip Ended", $"Your trip (booking #{assignment.BookingId}) has ended. We hope you enjoyed it!", NotificationType.General);
            if (assignment.VehicleId.HasValue)
            {
                var vehicle = assignment.Vehicle ?? await _context.Vehicles.FindAsync(assignment.VehicleId.Value);
                if (vehicle != null)
                {
                    await _notificationService.CreateAsync(
                        vehicle.OperatorId, "Trip Ended", $"Booking #{assignment.BookingId} has ended.", NotificationType.General);
                }
            }

            return NoContent();
        }

        // GET: api/assignments/booking/5
        [HttpGet("booking/{bookingId}")]
        public async Task<ActionResult<Assignment>> GetByBooking(int bookingId)
        {
            var assignment = await _context.Assignments
                .Include(a => a.Guide)
                .Include(a => a.Vehicle)
                .FirstOrDefaultAsync(a => a.BookingId == bookingId);

            if (assignment == null) return NotFound(new
            {
                message = "No assignment found for this booking." }); 
            return Ok(assignment);
        }

        // 🔥 BUSINESS-SPECIFIC OPERATION: Auto-Matching 
        // POST: api/assignments/auto-match 
        [HttpPost("auto-match")]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<AssignmentResultDto>> AutoMatch(AutoMatchRequestDto request)
        {
            var result = await _assignmentService.AutoMatchAsync(
                request.BookingId, request.Region, request.PreferredLanguage);

            if (!result.Success) return BadRequest(result);
            return Ok(result);
        }

        // 🔥 BUSINESS-SPECIFIC OPERATION: manual assign + confirm
        // POST: api/assignments/assign-confirm (Admin only) — the admin picks a guide and a
        // vehicle for a Pending package booking (the vehicle must be able to seat the
        // tourist's GroupSize) and this confirms the trip in one step.
        [HttpPost("assign-confirm")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> AssignAndConfirm(AssignConfirmDto dto)
        {
            var booking = await _context.Bookings.FindAsync(dto.BookingId);
            if (booking == null) return NotFound(new { message = "Booking not found." });

            // A package-purchase booking must be paid before the admin can assign & confirm —
            // otherwise the trip would be confirmed with no payment on record. (An AI-planned
            // trip has no PackageId at this point, so it's exempt — it pays AFTER confirmation.)
            if (booking.PackageId.HasValue && !booking.IsPaid)
                return BadRequest(new { message = "This tourist hasn't completed payment for this booking yet." });

            var alreadyAssigned = await _context.Assignments
                .AnyAsync(a => a.BookingId == booking.Id && a.Status != AssignmentStatus.Cancelled);
            if (alreadyAssigned)
                return BadRequest(new { message = "This booking already has a guide/vehicle assigned." });

            var guide = await _context.Guides.FindAsync(dto.GuideId);
            if (guide == null) return NotFound(new { message = "Guide not found." });
            if (!guide.IsAvailable) return BadRequest(new { message = "That guide is no longer available." });

            var vehicle = await _context.Vehicles.FindAsync(dto.VehicleId);
            if (vehicle == null) return NotFound(new { message = "Vehicle not found." });
            if (!vehicle.IsAvailable) return BadRequest(new { message = "That vehicle is no longer available." });
            if (vehicle.Capacity < booking.GroupSize)
                return BadRequest(new { message = $"This vehicle only seats {vehicle.Capacity}, but the group size is {booking.GroupSize}." });

            var assignment = new Assignment
            {
                BookingId = booking.Id,
                GuideId = guide.Id,
                VehicleId = vehicle.Id,
                Status = AssignmentStatus.Confirmed,
                AssignedAt = DateTime.UtcNow
            };
            _context.Assignments.Add(assignment);

            guide.IsAvailable = false;
            vehicle.IsAvailable = false;
            booking.Status = BookingStatus.Confirmed;
            booking.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            await _notificationService.CreateAsync(
                booking.TouristId, "Booking Confirmed",
                $"Your booking #{booking.Id} has been confirmed — a guide and vehicle have been assigned.",
                NotificationType.BookingApproved);
            await _notificationService.CreateAsync(
                guide.UserId, "New Trip Assigned",
                $"You've been assigned to booking #{booking.Id}.", NotificationType.General);
            await _notificationService.CreateAsync(
                vehicle.OperatorId, "New Trip Assigned",
                $"Your vehicle has been assigned to booking #{booking.Id}.", NotificationType.General);

            return Ok(new { message = "Guide and vehicle assigned — trip confirmed.", assignmentId = assignment.Id });
        }

        // PUT: api/assignments/5/status (Admin only)
        [HttpPut("{id}/status")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> UpdateStatus(int id, UpdateAssignmentStatusDto dto)
        {
            var assignment = await _context.Assignments.FindAsync(id);
            if (assignment == null) return NotFound(new { message = "Assignment not found." });

            if (!Enum.TryParse<AssignmentStatus>(dto.Status, true, out var newStatus))
                return BadRequest(new { message = "Invalid status value." });

            // Releasing a cancelled assignment frees the guide/vehicle again 
            if (newStatus == AssignmentStatus.Cancelled)
            {
                if (assignment.GuideId.HasValue)
                {
                    var guide = await _context.Guides.FindAsync(assignment.GuideId.Value);
                    if (guide != null) guide.IsAvailable = true;
                }
                if (assignment.VehicleId.HasValue)
                {
                    var vehicle = await _context.Vehicles.FindAsync(assignment.VehicleId.Value);
                    if (vehicle != null) vehicle.IsAvailable = true;
                }
            }

            assignment.Status = newStatus;
            await _context.SaveChangesAsync();
            return NoContent();
        }
    }
}