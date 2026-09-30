using CeyloraAPI.Data;
using CeyloraAPI.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CeyloraAPI.Controllers
{
    // Aggregate stats for the Admin dashboard's Analytics page.
    [ApiController]
    [Route("api/analytics")]
    [Authorize(Roles = "Admin")]
    public class AnalyticsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public AnalyticsController(AppDbContext context)
        {
            _context = context;
        }

        // GET: api/analytics/overview
        [HttpGet("overview")]
        public async Task<IActionResult> GetOverview()
        {
            var totalUsers = await _context.Users.CountAsync();
            var totalTourists = await _context.Users.CountAsync(u => u.Role == UserRole.Tourist);
            var totalGuideUsers = await _context.Users.CountAsync(u => u.Role == UserRole.Guide);

            var bookings = await _context.Bookings.ToListAsync();
            var completedOrConfirmed = bookings.Where(b => b.Status == BookingStatus.Confirmed || b.Status == BookingStatus.OnGoing || b.Status == BookingStatus.Ended).ToList();
            var totalRevenue = completedOrConfirmed.Sum(b => b.TotalPrice);

            return Ok(new
            {
                totalUsers,
                totalTourists,
                totalGuideUsers,
                totalBookings = bookings.Count,
                pendingBookings = bookings.Count(b => b.Status == BookingStatus.Pending),
                confirmedBookings = bookings.Count(b => b.Status == BookingStatus.Confirmed),
                onGoingBookings = bookings.Count(b => b.Status == BookingStatus.OnGoing),
                completedBookings = bookings.Count(b => b.Status == BookingStatus.Ended),
                cancelledBookings = bookings.Count(b => b.Status == BookingStatus.Cancelled),
                rejectedBookings = bookings.Count(b => b.Status == BookingStatus.Rejected),
                totalRevenue,
                avgBookingValue = completedOrConfirmed.Count > 0 ? totalRevenue / completedOrConfirmed.Count : 0,
                totalDestinations = await _context.Destinations.CountAsync(),
                totalHotels = await _context.Hotels.CountAsync(),
                totalVehicles = await _context.Vehicles.CountAsync(),
                totalPackages = await _context.Packages.CountAsync(),
                totalGuides = await _context.Guides.CountAsync(),
            });
        }

        // GET: api/analytics/bookings-over-time?days=30
        [HttpGet("bookings-over-time")]
        public async Task<IActionResult> GetBookingsOverTime([FromQuery] int days = 30)
        {
            var since = DateTime.UtcNow.Date.AddDays(-days + 1);
            var bookings = await _context.Bookings
                .Where(b => b.CreatedAt >= since)
                .ToListAsync();

            var byDay = Enumerable.Range(0, days)
                .Select(offset => since.AddDays(offset))
                .Select(day => new
                {
                    date = day.ToString("yyyy-MM-dd"),
                    count = bookings.Count(b => b.CreatedAt.Date == day),
                    revenue = bookings.Where(b => b.CreatedAt.Date == day &&
                        (b.Status == BookingStatus.Confirmed || b.Status == BookingStatus.OnGoing || b.Status == BookingStatus.Ended))
                        .Sum(b => b.TotalPrice)
                })
                .ToList();

            return Ok(byDay);
        }

        // GET: api/analytics/user-growth?days=30
        [HttpGet("user-growth")]
        public async Task<IActionResult> GetUserGrowth([FromQuery] int days = 30)
        {
            var since = DateTime.UtcNow.Date.AddDays(-days + 1);
            var users = await _context.Users
                .Where(u => u.CreatedAt >= since)
                .ToListAsync();

            var byDay = Enumerable.Range(0, days)
                .Select(offset => since.AddDays(offset))
                .Select(day => new
                {
                    date = day.ToString("yyyy-MM-dd"),
                    newUsers = users.Count(u => u.CreatedAt.Date == day)
                })
                .ToList();

            return Ok(byDay);
        }

        // GET: api/analytics/top-destinations?limit=6
        // Ranks destinations by how many bookings included them (via Package -> PackageDestinations).
        [HttpGet("top-destinations")]
        public async Task<IActionResult> GetTopDestinations([FromQuery] int limit = 6)
        {
            var bookings = await _context.Bookings
                .Include(b => b.Package).ThenInclude(p => p.PackageDestinations).ThenInclude(pd => pd.Destination)
                .Where(b => b.Status != BookingStatus.Cancelled && b.Status != BookingStatus.Rejected)
                .ToListAsync();

            var counts = new Dictionary<string, int>();
            foreach (var b in bookings)
            {
                if (b.Package?.PackageDestinations == null) continue;
                foreach (var pd in b.Package.PackageDestinations)
                {
                    var name = pd.Destination?.Name ?? "Unknown";
                    counts[name] = counts.GetValueOrDefault(name) + 1;
                }
            }

            var top = counts
                .OrderByDescending(kv => kv.Value)
                .Take(limit)
                .Select(kv => new { name = kv.Key, bookings = kv.Value });

            return Ok(top);
        }

        // GET: api/analytics/guide-performance?limit=6
        [HttpGet("guide-performance")]
        public async Task<IActionResult> GetGuidePerformance([FromQuery] int limit = 6)
        {
            var guides = await _context.Guides
                .Include(g => g.User)
                .ToListAsync();

            var completedAssignments = await _context.Assignments
                .Include(a => a.Booking)
                .Where(a => a.GuideId != null && a.Status != AssignmentStatus.Cancelled &&
                            a.Booking.Status == BookingStatus.Ended)
                .ToListAsync();

            var result = guides
                .Select(g => new
                {
                    guideId = g.Id,
                    name = g.User?.Name ?? "Guide",
                    region = g.Region,
                    rating = g.Rating,
                    completedTrips = completedAssignments.Count(a => a.GuideId == g.Id)
                })
                .OrderByDescending(g => g.completedTrips)
                .ThenByDescending(g => g.rating)
                .Take(limit);

            return Ok(result);
        }
    }
}
