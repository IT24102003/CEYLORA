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
    public class PackagesController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IPricingService _pricingService;

        public PackagesController(AppDbContext context, IPricingService pricingService)
        {
            _context = context;
            _pricingService = pricingService;
        }

        // GET: api/packages?published=true&search=beach&page=1&pageSize=10
        // Includes destinations (with coords, for the route) & hotels & the suggested
        // guide/vehicle — small admin-facing table, so eagerly loading all of this is fine.
        [HttpGet]
        public async Task<IActionResult> GetAll(
            [FromQuery] bool? published,
            [FromQuery] string? search,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            var query = _context.Packages
                .Include(p => p.PackageDestinations).ThenInclude(pd => pd.Destination)
                .Include(p => p.PackageHotels).ThenInclude(ph => ph.Hotel)
                .Include(p => p.SuggestedGuide).ThenInclude(g => g!.User)
                .Include(p => p.SuggestedVehicle)
                .AsQueryable();

            if (published.HasValue)
                query = query.Where(p => p.IsPublished == published.Value);

            if (!string.IsNullOrWhiteSpace(search))
                query = query.Where(p => p.Name.ToLower().Contains(search.ToLower())
                                       || (p.Description != null && p.Description.ToLower().Contains(search.ToLower())));

            var totalCount = await query.CountAsync();
            var items = await query
                .OrderByDescending(p => p.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            return Ok(new PagedResultDto<object>
            {
                Items = items.Select(ProjectPackage).ToList(),
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        // GET: api/packages/5
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var projected = await LoadProjectedPackage(id);
            if (projected == null) return NotFound(new { message = "Package not found." });
            return Ok(projected);
        }

        private async Task<object?> LoadProjectedPackage(int id)
        {
            var package = await _context.Packages
                .Include(p => p.PackageDestinations).ThenInclude(pd => pd.Destination)
                .Include(p => p.PackageHotels).ThenInclude(ph => ph.Hotel)
                .Include(p => p.SuggestedGuide).ThenInclude(g => g!.User)
                .Include(p => p.SuggestedVehicle)
                .FirstOrDefaultAsync(p => p.Id == id);

            return package == null ? null : ProjectPackage(package);
        }

        // Shapes a Package (with its destinations/hotels/suggested guide&vehicle already
        // Included) into the JSON the admin panel renders — destinations come back ordered
        // by DayNumber so the frontend can draw the route (and a Google Maps link) straight
        // from this list the moment a destination is added, with no separate "build route" step.
        private static object ProjectPackage(Package p) => new
        {
            p.Id,
            p.Name,
            p.Description,
            p.BasePrice,
            p.DurationDays,
            p.MaxPeople,
            p.IsPublished,
            p.CreatedAt,
            suggestedGuideId = p.SuggestedGuideId,
            suggestedGuideName = p.SuggestedGuide?.User?.Name,
            suggestedVehicleId = p.SuggestedVehicleId,
            suggestedVehicleName = p.SuggestedVehicle != null ? (p.SuggestedVehicle.Name ?? p.SuggestedVehicle.Type) : null,
            destinations = p.PackageDestinations
                .OrderBy(pd => pd.DayNumber)
                .Select(pd => new
                {
                    pd.Id,
                    destinationId = pd.DestinationId,
                    pd.DayNumber,
                    name = pd.Destination.Name,
                    region = pd.Destination.Region,
                    latitude = pd.Destination.Latitude,
                    longitude = pd.Destination.Longitude,
                    imageUrl = pd.Destination.ImageUrl
                }),
            hotels = p.PackageHotels.Select(ph => new
            {
                ph.Id,
                hotelId = ph.HotelId,
                name = ph.Hotel.Name,
                region = ph.Hotel.Region,
                imageUrl = ph.Hotel.ImageUrl,
                pricePerNight = ph.Hotel.PricePerNight
            })
        };

        // POST: api/packages (Admin only)
        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Create(PackageDto dto)
        {
            var package = new Package
            {
                Name = dto.Name,
                Description = dto.Description,
                BasePrice = dto.BasePrice,
                DurationDays = dto.DurationDays,
                MaxPeople = dto.MaxPeople > 0 ? dto.MaxPeople : 4,
                SuggestedGuideId = dto.SuggestedGuideId,
                SuggestedVehicleId = dto.SuggestedVehicleId,
                IsPublished = dto.IsPublished,
                CreatedAt = DateTime.UtcNow
            };

            _context.Packages.Add(package);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetById), new { id = package.Id }, package);
        }

        // PUT: api/packages/5 (Admin only)
        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(int id, PackageDto dto)
        {
            var package = await _context.Packages.FindAsync(id);
            if (package == null) return NotFound(new { message = "Package not found." });

            package.Name = dto.Name;
            package.Description = dto.Description;
            package.BasePrice = dto.BasePrice;
            package.DurationDays = dto.DurationDays;
            package.MaxPeople = dto.MaxPeople > 0 ? dto.MaxPeople : 4;
            package.SuggestedGuideId = dto.SuggestedGuideId;
            package.SuggestedVehicleId = dto.SuggestedVehicleId;
            package.IsPublished = dto.IsPublished;

            await _context.SaveChangesAsync();
            return NoContent();
        }

        // POST: api/packages/5/destinations (Admin only) — the route is simply the
        // destinations in DayNumber order, so adding one here is all "building the route" takes.
        [HttpPost("{id}/destinations")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> AddDestination(int id, AddPackageDestinationDto dto)
        {
            var packageExists = await _context.Packages.AnyAsync(p => p.Id == id);
            if (!packageExists) return NotFound(new { message = "Package not found." });

            var destinationExists = await _context.Destinations.AnyAsync(d => d.Id == dto.DestinationId);
            if (!destinationExists) return NotFound(new { message = "Destination not found." });

            _context.PackageDestinations.Add(new PackageDestination
            {
                PackageId = id,
                DestinationId = dto.DestinationId,
                DayNumber = dto.DayNumber
            });
            await _context.SaveChangesAsync();
            return Ok(await LoadProjectedPackage(id));
        }

        // DELETE: api/packages/5/destinations/12 (Admin only) — 12 is the PackageDestination row id
        [HttpDelete("{id}/destinations/{packageDestinationId}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> RemoveDestination(int id, int packageDestinationId)
        {
            var pd = await _context.PackageDestinations
                .FirstOrDefaultAsync(x => x.Id == packageDestinationId && x.PackageId == id);
            if (pd == null) return NotFound(new { message = "Package destination not found." });

            _context.PackageDestinations.Remove(pd);
            await _context.SaveChangesAsync();
            return NoContent();
        }

        // POST: api/packages/5/hotels (Admin only)
        [HttpPost("{id}/hotels")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> AddHotel(int id, AddPackageHotelDto dto)
        {
            var packageExists = await _context.Packages.AnyAsync(p => p.Id == id);
            if (!packageExists) return NotFound(new { message = "Package not found." });

            var hotelExists = await _context.Hotels.AnyAsync(h => h.Id == dto.HotelId);
            if (!hotelExists) return NotFound(new { message = "Hotel not found." });

            _context.PackageHotels.Add(new PackageHotel { PackageId = id, HotelId = dto.HotelId });
            await _context.SaveChangesAsync();
            return Ok(await LoadProjectedPackage(id));
        }

        // DELETE: api/packages/5/hotels/7 (Admin only) — 7 is the PackageHotel row id
        [HttpDelete("{id}/hotels/{packageHotelId}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> RemoveHotel(int id, int packageHotelId)
        {
            var ph = await _context.PackageHotels
                .FirstOrDefaultAsync(x => x.Id == packageHotelId && x.PackageId == id);
            if (ph == null) return NotFound(new { message = "Package hotel not found." });

            _context.PackageHotels.Remove(ph);
            await _context.SaveChangesAsync();
            return NoContent();
        }

        // DELETE: api/packages/5 (Admin only)
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var package = await _context.Packages.FindAsync(id);
            if (package == null) return NotFound(new { message = "Package not found." });

            _context.Packages.Remove(package);
            await _context.SaveChangesAsync();
            return NoContent();
        }

        // 🔥 BUSINESS-SPECIFIC OPERATION: Dynamic Price Quote
        // POST: api/packages/5/quote
        [HttpPost("{id}/quote")]
        public async Task<ActionResult<PriceQuoteResponseDto>> GetPriceQuote(int id, PriceQuoteRequestDto request)
        {
            var package = await _context.Packages.FindAsync(id);
            if (package == null) return NotFound(new { message = "Package not found." });

            if (request.GroupSize < 1)
                return BadRequest(new { message = "Group size must be at least 1." });

            var quote = _pricingService.CalculatePrice(package, request.GroupSize, request.TravelDate);
            return Ok(quote);
        }
    }
}