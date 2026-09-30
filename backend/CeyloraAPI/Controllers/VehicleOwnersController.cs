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
    [Route("api/vehicle-owners")]
    public class VehicleOwnersController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly INotificationService _notificationService;

        public VehicleOwnersController(AppDbContext context, INotificationService notificationService)
        {
            _context = context;
            _notificationService = notificationService;
        }

        // GET: api/vehicle-owners/me
        [HttpGet("me")]
        [Authorize(Roles = "VehicleOwner")]
        public async Task<IActionResult> GetMyProfile()
        {
            var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            var owner = await _context.VehicleOwners.FirstOrDefaultAsync(v => v.UserId == userId);
            if (owner == null) return NotFound(new { message = "No vehicle owner profile found for this account." });
            return Ok(owner);
        }

        // GET: api/vehicle-owners/pending (Admin only)
        [HttpGet("pending")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetPending()
        {
            var pending = await _context.VehicleOwners
                .Include(v => v.User)
                .Where(v => !v.IsVerified)
                .ToListAsync();

            var result = new List<object>();
            foreach (var vo in pending)
            {
                var vehicles = await _context.Vehicles.Include(v => v.Images)
                    .Where(v => v.OperatorId == vo.UserId).ToListAsync();

                result.Add(new
                {
                    id = vo.Id,
                    userId = vo.UserId,
                    name = vo.User.Name,
                    email = vo.User.Email,
                    age = vo.User.Age,
                    mobileNumber = vo.User.MobileNumber,
                    region = vo.Region,
                    nicNumber = vo.NicNumber,
                    drivingLicensePhotoUrl = vo.DrivingLicensePhotoUrl,
                    country = vo.User.Country,
                    createdAt = vo.User.CreatedAt,
                    vehicles = vehicles.Select(v => new
                    {
                        id = v.Id,
                        type = v.Type,
                        name = v.Name,
                        manufacturerYear = v.ManufacturerYear,
                        capacity = v.Capacity,
                        images = v.Images.Select(i => i.ImageUrl)
                    })
                });
            }

            return Ok(result);
        }

        // PUT: api/vehicle-owners/5/verify (Admin only)
        [HttpPut("{id}/verify")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Verify(int id, VerifyDto dto)
        {
            var owner = await _context.VehicleOwners.FindAsync(id);
            if (owner == null) return NotFound(new { message = "Vehicle owner not found." });

            owner.IsVerified = dto.Approve;
            owner.VerificationNote = dto.Note;
            await _context.SaveChangesAsync();

            await _notificationService.CreateAsync(
                owner.UserId,
                dto.Approve ? "Vehicle Owner Application Approved!" : "Vehicle Owner Application Needs Attention",
                dto.Approve
                    ? "Your vehicle owner profile has been verified. Your vehicle is now visible to tourists!"
                    : $"Your application was not approved.{(string.IsNullOrWhiteSpace(dto.Note) ? "" : $" Reason: {dto.Note}")}",
                NotificationType.General);

            return NoContent();
        }

        // GET: api/vehicle-owners/5/earnings — completed-trip earnings summary (estimate)
        [HttpGet("{id}/earnings")]
        [Authorize(Roles = "VehicleOwner,Admin")]
        public async Task<IActionResult> GetEarnings(int id)
        {
            var owner = await _context.VehicleOwners.FindAsync(id);
            if (owner == null) return NotFound(new { message = "Vehicle owner not found." });

            if (!User.IsInRole("Admin"))
            {
                var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
                if (owner.UserId != userId) return Forbid();
            }

            var vehicleIds = await _context.Vehicles
                .Where(v => v.OperatorId == owner.UserId)
                .Select(v => v.Id)
                .ToListAsync();

            // The schema doesn't persist the actual distance driven per completed trip, so
            // earnings are ESTIMATED using the vehicle's own per-km rate (Car 120 / Van 180 /
            // Bus 280) x an assumed average driving distance per day x the trip's duration.
            var completed = await _context.Assignments
                .Where(a => a.VehicleId.HasValue && vehicleIds.Contains(a.VehicleId.Value))
                .Include(a => a.Booking).ThenInclude(b => b.Package)
                .Include(a => a.Vehicle)
                .Where(a => a.Booking.Status == BookingStatus.Ended)
                .OrderByDescending(a => a.Booking.UpdatedAt)
                .ToListAsync();

            var trips = completed.Select(a =>
            {
                var days = a.Booking.Package?.DurationDays ?? a.Booking.CustomTripDurationDays ?? 1;
                var pricePerKm = a.Vehicle?.PricePerKm ?? 0;
                var estimatedEarning = pricePerKm * (decimal)VehiclePricing.AssumedKmPerDay * days;
                return new
                {
                    bookingId = a.BookingId,
                    packageName = a.Booking.Package?.Name ?? a.Booking.CustomTripObjective ?? "",
                    vehicleName = a.Vehicle != null ? (a.Vehicle.Name ?? a.Vehicle.Type) : "",
                    pricePerKm,
                    durationDays = days,
                    completedAt = a.Booking.UpdatedAt,
                    estimatedEarning
                };
            }).ToList();

            return Ok(new
            {
                vehicleOwnerId = id,
                estimatedKmPerDay = VehiclePricing.AssumedKmPerDay,
                totalCompletedTrips = trips.Count,
                totalEstimatedEarnings = trips.Sum(t => t.estimatedEarning),
                trips
            });
        }
    }
}
