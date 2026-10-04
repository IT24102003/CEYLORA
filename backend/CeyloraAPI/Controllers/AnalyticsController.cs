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
            // Previously: 14 sequential round trips (9 separate CountAsync calls, one
            // ToListAsync pulling every booking, then more counting in memory) — by far
            // the heaviest endpoint on this page, and the one most likely to land on a
            // slow beat from Supabase's free-tier pooler. Folding every count into one
            // GroupBy(_ => 1) projection lets EF Core translate the whole thing into a
            // single SQL statement (each count becomes a scalar subquery Postgres runs
            // server-side), so this is now one round trip instead of fourteen.
            var stats = await _context.Users
                .GroupBy(_ => 1)
                .Select(g => new
                {
                    totalUsers = g.Count(),
                    totalTourists = g.Count(u => u.Role == UserRole.Tourist),
                    totalGuideUsers = g.Count(u => u.Role == UserRole.Guide),
                    totalBookings = _context.Bookings.Count(),
                    pendingBookings = _context.Bookings.Count(b => b.Status == BookingStatus.Pending),
                    confirmedBookings = _context.Bookings.Count(b => b.Status == BookingStatus.Confirmed),
                    onGoingBookings = _context.Bookings.Count(b => b.Status == BookingStatus.OnGoing),
                    completedBookings = _context.Bookings.Count(b => b.Status == BookingStatus.Ended),
                    cancelledBookings = _context.Bookings.Count(b => b.Status == BookingStatus.Cancelled),
                    rejectedBookings = _context.Bookings.Count(b => b.Status == BookingStatus.Rejected),
                    completedOrConfirmedCount = _context.Bookings.Count(b =>
                        b.Status == BookingStatus.Confirmed || b.Status == BookingStatus.OnGoing || b.Status == BookingStatus.Ended),
                    totalRevenue = _context.Bookings
                        .Where(b => b.Status == BookingStatus.Confirmed || b.Status == BookingStatus.OnGoing || b.Status == BookingStatus.Ended)
                        .Sum(b => (decimal?)b.TotalPrice) ?? 0,
                    totalDestinations = _context.Destinations.Count(),
                    totalHotels = _context.Hotels.Count(),
                    totalVehicles = _context.Vehicles.Count(),
                    totalPackages = _context.Packages.Count(),
                    totalGuides = _context.Guides.Count(),
                })
                .FirstOrDefaultAsync();

            // No users at all (fresh DB) means the GroupBy produces no rows — fall back
            // to zeros instead of a null-reference on the empty dashboard.
            if (stats == null)
                return Ok(new
                {
                    totalUsers = 0, totalTourists = 0, totalGuideUsers = 0, totalBookings = 0,
                    pendingBookings = 0, confirmedBookings = 0, onGoingBookings = 0, completedBookings = 0,
                    cancelledBookings = 0, rejectedBookings = 0, totalRevenue = 0m, avgBookingValue = 0m,
                    totalDestinations = 0, totalHotels = 0, totalVehicles = 0, totalPackages = 0, totalGuides = 0,
                });

            return Ok(new
            {
                stats.totalUsers,
                stats.totalTourists,
                stats.totalGuideUsers,
                stats.totalBookings,
                stats.pendingBookings,
                stats.confirmedBookings,
                stats.onGoingBookings,
                stats.completedBookings,
                stats.cancelledBookings,
                stats.rejectedBookings,
                stats.totalRevenue,
                avgBookingValue = stats.completedOrConfirmedCount > 0 ? stats.totalRevenue / stats.completedOrConfirmedCount : 0,
                stats.totalDestinations,
                stats.totalHotels,
                stats.totalVehicles,
                stats.totalPackages,
                stats.totalGuides,
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
            // Previously: two separate round trips (all Guides, then all matching
            // Assignments+Booking) joined/counted in memory. Each round trip is a
            // chance to hit a slow beat on Supabase's free-tier pooler, and this
            // endpoint paid that cost twice. Doing the count as a correlated
            // subquery lets EF Core translate the whole thing into one SQL
            // statement — one round trip, and the counting happens in Postgres
            // instead of after pulling every row over the wire.
            var result = await _context.Guides
                .Include(g => g.User)
                .Select(g => new
                {
                    guideId = g.Id,
                    name = g.User != null ? g.User.Name : "Guide",
                    region = g.Region,
                    rating = g.Rating,
                    completedTrips = _context.Assignments.Count(a =>
                        a.GuideId == g.Id &&
                        a.Status != AssignmentStatus.Cancelled &&
                        a.Booking.Status == BookingStatus.Ended)
                })
                .OrderByDescending(g => g.completedTrips)
                .ThenByDescending(g => g.rating)
                .Take(limit)
                .ToListAsync();

            return Ok(result);
        }
    }
}
