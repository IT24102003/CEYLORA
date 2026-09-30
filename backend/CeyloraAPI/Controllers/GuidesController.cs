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
    public class GuidesController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly INotificationService _notificationService;

        public GuidesController(AppDbContext context, INotificationService notificationService)
        {
            _context = context;
            _notificationService = notificationService;
        }

        // GET: api/guides/me — the logged-in Guide's own guide profile
        [HttpGet("me")]
        [Authorize(Roles = "Guide")]
        public async Task<ActionResult<Guide>> GetMyProfile()
        {
            var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            var guide = await _context.Guides.FirstOrDefaultAsync(g => g.UserId == userId);
            if (guide == null) return NotFound(new { message = "No guide profile found for this account." });
            return Ok(guide);
        }

        // GET: api/guides/5/earnings — completed-trip earnings summary (estimate, see note below)
        [HttpGet("{id}/earnings")]
        [Authorize(Roles = "Guide,Admin")]
        public async Task<IActionResult> GetEarnings(int id)
        {
            var guide = await _context.Guides.FindAsync(id);
            if (guide == null) return NotFound(new { message = "Guide not found." });

            // A guide may only see their own earnings; Admins can view any guide's.
            if (!User.IsInRole("Admin"))
            {
                var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
                if (guide.UserId != userId) return Forbid();
            }

            // The schema has no stored guide fee, so earnings are ESTIMATED as a flat
            // per-day rate (the same figure the tourist sees on the trip-review screen).
            const decimal flatFeePerDay = 2500m;

            var completed = await _context.Assignments
                .Where(a => a.GuideId == id)
                .Include(a => a.Booking).ThenInclude(b => b.Package)
                .Where(a => a.Booking.Status == BookingStatus.Ended)
                .OrderByDescending(a => a.Booking.UpdatedAt)
                .ToListAsync();

            var trips = completed.Select(a => new
            {
                bookingId = a.BookingId,
                packageName = a.Booking.Package?.Name ?? a.Booking.CustomTripObjective ?? "",
                durationDays = a.Booking.Package?.DurationDays ?? a.Booking.CustomTripDurationDays ?? 1,
                completedAt = a.Booking.UpdatedAt,
                estimatedEarning = flatFeePerDay * (a.Booking.Package?.DurationDays ?? a.Booking.CustomTripDurationDays ?? 1)
            }).ToList();

            return Ok(new
            {
                guideId = id,
                flatFeePerDay,
                totalCompletedTrips = trips.Count,
                totalEstimatedEarnings = trips.Sum(t => t.estimatedEarning),
                trips
            });
        }

        // GET: api/guides/pending (Admin only) — guides awaiting verification, with applicant details
        [HttpGet("pending")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetPending()
        {
            var pending = await _context.Guides
                .Include(g => g.User)
                .Where(g => !g.IsVerified)
                .Select(g => new
                {
                    id = g.Id,
                    userId = g.UserId,
                    name = g.User.Name,
                    email = g.User.Email,
                    age = g.User.Age,
                    mobileNumber = g.User.MobileNumber,
                    region = g.Region,
                    languages = g.Languages,
                    nicNumber = g.NicNumber,
                    tourismIdPhotoUrl = g.TourismIdPhotoUrl,
                    country = g.User.Country,
                    createdAt = g.User.CreatedAt
                })
                .ToListAsync();

            return Ok(pending);
        }

        // PUT: api/guides/5/verify (Admin only) — approve or reject a pending guide application
        [HttpPut("{id}/verify")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Verify(int id, VerifyDto dto)
        {
            var guide = await _context.Guides.FindAsync(id);
            if (guide == null) return NotFound(new { message = "Guide not found." });

            guide.IsVerified = dto.Approve;
            guide.VerificationNote = dto.Note;
            await _context.SaveChangesAsync();

            await _notificationService.CreateAsync(
                guide.UserId,
                dto.Approve ? "Guide Application Approved!" : "Guide Application Needs Attention",
                dto.Approve
                    ? "Your guide profile has been verified. You're now visible to tourists!"
                    : $"Your guide application was not approved.{(string.IsNullOrWhiteSpace(dto.Note) ? "" : $" Reason: {dto.Note}")}",
                NotificationType.General);

            return NoContent();
        }

        // GET: api/guides?region=Kandy&available=true&search=english&page=1&pageSize=10
        // verifiedOnly=true (default) hides guides pending Admin review — pass false from the
        // admin panel to see everyone, including pending applications.
        [HttpGet]
        public async Task<IActionResult> GetAll(
            [FromQuery] string? region,
            [FromQuery] bool? available,
            [FromQuery] string? search,
            [FromQuery] bool verifiedOnly = true,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            var query = _context.Guides.Include(g => g.User).AsQueryable();

            if (verifiedOnly)
                query = query.Where(g => g.IsVerified);

            if (!string.IsNullOrWhiteSpace(region))
                query = query.Where(g => g.Region.ToLower() == region.ToLower());

            if (available.HasValue)
                query = query.Where(g => g.IsAvailable == available.Value);

            if (!string.IsNullOrWhiteSpace(search))
                query = query.Where(g => (g.Languages != null && g.Languages.ToLower().Contains(search.ToLower()))
                                       || g.Region.ToLower().Contains(search.ToLower()));

            var totalCount = await query.CountAsync();
            var items = await query
                .OrderByDescending(g => g.Rating)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(g => new
                {
                    g.Id,
                    g.UserId,
                    g.Languages,
                    g.Region,
                    g.Rating,
                    g.IsAvailable,
                    g.IsVerified,
                    name = g.User.Name,
                    profilePictureUrl = g.User.ProfilePictureUrl,
                    country = g.User.Country,
                    mobileNumber = g.User.MobileNumber
                })
                .ToListAsync();

            return Ok(new
            {
                items,
                totalCount,
                page,
                pageSize
            });
        }

        // GET: api/guides/5
        [HttpGet("{id}")]
        public async Task<ActionResult<Guide>> GetById(int id)
        {
            var guide = await _context.Guides.FindAsync(id);
            if (guide == null) return NotFound(new { message = "Guide not found." });
            return Ok(guide);
        }

        // POST: api/guides (Admin only)
        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<Guide>> Create(GuideDto dto)
        {
            var userExists = await _context.Users.AnyAsync(u => u.Id == dto.UserId);
            if (!userExists) return NotFound(new { message = "User not found." });

            var guide = new Guide
            {
                UserId = dto.UserId,
                Languages = dto.Languages,
                Region = dto.Region,
                NicNumber = dto.NicNumber,
                Rating = 0,
                IsAvailable = dto.IsAvailable,
                IsVerified = true // admin-linked directly, no document review needed
            };

            _context.Guides.Add(guide);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetById), new { id = guide.Id }, guide);
        }

        // PUT: api/guides/5
        [HttpPut("{id}")]
        [Authorize]
        public async Task<IActionResult> Update(int id, GuideDto dto)
        {
            var guide = await _context.Guides.FindAsync(id);
            if (guide == null) return NotFound(new { message = "Guide not found." });

            guide.Languages = dto.Languages;
            guide.Region = dto.Region;
            guide.IsAvailable = dto.IsAvailable;

            await _context.SaveChangesAsync();
            return NoContent();
        }

        // PUT: api/guides/5/availability
        [HttpPut("{id}/availability")]
        [Authorize(Roles = "Guide,Admin")]
        public async Task<IActionResult> ToggleAvailability(int id, [FromBody] bool isAvailable)
        {
            var guide = await _context.Guides.FindAsync(id);
            if (guide == null) return NotFound(new { message = "Guide not found." });

            // 🔥 Can't flip back to "Available" while on an active trip (Confirmed or OnGoing) —
            // that would let them get double-booked onto a second trip at the same time.
            if (isAvailable)
            {
                var hasActiveTrip = await _context.Assignments
                    .Include(a => a.Booking)
                    .AnyAsync(a => a.GuideId == id &&
                        (a.Booking.Status == BookingStatus.Confirmed || a.Booking.Status == BookingStatus.OnGoing));
                if (hasActiveTrip)
                    return BadRequest(new { message = "Can't mark yourself available while you have an active/on-going trip." });
            }

            guide.IsAvailable = isAvailable;
            await _context.SaveChangesAsync();
            return NoContent();
        }

        // DELETE: api/guides/5 (Admin only)
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var guide = await _context.Guides.FindAsync(id);
            if (guide == null) return NotFound(new { message = "Guide not found." });

            _context.Guides.Remove(guide);
            await _context.SaveChangesAsync();
            return NoContent();
        }
    }
}
