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
    public class VehiclesController : ControllerBase
    {
        private readonly AppDbContext _context;

        public VehiclesController(AppDbContext context)
        {
            _context = context;
        }

        // GET: api/vehicles/my — the logged-in Vehicle Owner's own vehicles
        [HttpGet("my")]
        [Authorize(Roles = "VehicleOwner")]
        public async Task<IActionResult> GetMyVehicles()
        {
            var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
            var vehicles = await _context.Vehicles.Include(v => v.Images).Where(v => v.OperatorId == userId).ToListAsync();
            return Ok(vehicles);
        }

        // GET: api/vehicles?region=Kandy&type=Van&available=true&search=luxury&sortBy=rating&page=1&pageSize=10
        // verifiedOnly=true (default) hides vehicles whose owner has an unverified VehicleOwner
        // profile. Vehicles added directly by an Admin (no VehicleOwner row) are unaffected.
        [HttpGet]
        public async Task<IActionResult> GetAll(
            [FromQuery] string? region,
            [FromQuery] string? type,
            [FromQuery] bool? available,
            [FromQuery] string? search,
            [FromQuery] string? sortBy,
            [FromQuery] bool verifiedOnly = true,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            var query = _context.Vehicles.Include(v => v.Images).Include(v => v.Operator).AsQueryable();

            if (verifiedOnly)
            {
                var unverifiedOperatorIds = await _context.VehicleOwners
                    .Where(vo => !vo.IsVerified)
                    .Select(vo => vo.UserId)
                    .ToListAsync();
                query = query.Where(v => !unverifiedOperatorIds.Contains(v.OperatorId));
            }

            if (!string.IsNullOrWhiteSpace(region))
                query = query.Where(v => v.Region.ToLower() == region.ToLower());

            if (!string.IsNullOrWhiteSpace(type))
                query = query.Where(v => v.Type.ToLower() == type.ToLower());

            if (available.HasValue)
                query = query.Where(v => v.IsAvailable == available.Value);

            if (!string.IsNullOrWhiteSpace(search))
                query = query.Where(v => v.Type.ToLower().Contains(search.ToLower())
                                       || v.Region.ToLower().Contains(search.ToLower())
                                       || (v.Name != null && v.Name.ToLower().Contains(search.ToLower())));

            query = sortBy?.ToLower() switch
            {
                "rating" => query.OrderByDescending(v => v.Rating),
                "price" => query.OrderBy(v => v.PricePerKm),
                _ => query.OrderBy(v => v.Id)
            };

            var totalCount = await query.CountAsync();
            var items = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(v => new
                {
                    v.Id,
                    v.OperatorId,
                    v.Type,
                    v.Name,
                    v.ManufacturerYear,
                    v.Capacity,
                    v.Region,
                    v.PricePerKm,
                    v.IsAvailable,
                    v.Rating,
                    images = v.Images.Select(i => new { i.Id, i.ImageUrl, i.IsCover }),
                    ownerName = v.Operator.Name,
                    ownerCountry = v.Operator.Country,
                    ownerPhone = v.Operator.MobileNumber
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

        // GET: api/vehicles/5
        [HttpGet("{id}")]
        public async Task<ActionResult<Vehicle>> GetById(int id)
        {
            var vehicle = await _context.Vehicles.Include(v => v.Images).FirstOrDefaultAsync(v => v.Id == id);
            if (vehicle == null) return NotFound(new { message = "Vehicle not found." });
            return Ok(vehicle);
        }

        // POST: api/vehicles (Admin only)
        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<Vehicle>> Create(VehicleDto dto)
        {
            var operatorExists = await _context.Users.AnyAsync(u => u.Id == dto.OperatorId);
            if (!operatorExists) return NotFound(new { message = "Operator user not found." });

            var vehicle = new Vehicle
            {
                OperatorId = dto.OperatorId,
                Type = dto.Type,
                Name = dto.Name,
                ManufacturerYear = dto.ManufacturerYear,
                Capacity = dto.Capacity,
                Region = dto.Region,
                IsAvailable = dto.IsAvailable,
                // Fall back to the fixed per-type rate (Car 120 / Van 180 / Bus 280 per km)
                // if the admin didn't set an explicit price.
                PricePerKm = dto.PricePerKm > 0 ? dto.PricePerKm : VehiclePricing.GetPricePerKm(dto.Type)
            };

            _context.Vehicles.Add(vehicle);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetById), new { id = vehicle.Id }, vehicle);
        }

        // PUT: api/vehicles/5 (Admin only)
        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(int id, VehicleDto dto)
        {
            var vehicle = await _context.Vehicles.FindAsync(id);
            if (vehicle == null) return NotFound(new { message = "Vehicle not found." });

            vehicle.Type = dto.Type;
            vehicle.Name = dto.Name;
            vehicle.ManufacturerYear = dto.ManufacturerYear;
            vehicle.Capacity = dto.Capacity;
            vehicle.Region = dto.Region;
            vehicle.IsAvailable = dto.IsAvailable;
            vehicle.PricePerKm = dto.PricePerKm;

            await _context.SaveChangesAsync();
            return NoContent();
        }

        // PUT: api/vehicles/5/availability — Admin, or the Vehicle Owner who owns it
        [HttpPut("{id}/availability")]
        [Authorize(Roles = "VehicleOwner,Admin")]
        public async Task<IActionResult> ToggleAvailability(int id, [FromBody] bool isAvailable)
        {
            var vehicle = await _context.Vehicles.FindAsync(id);
            if (vehicle == null) return NotFound(new { message = "Vehicle not found." });

            if (!User.IsInRole("Admin"))
            {
                var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
                if (vehicle.OperatorId != userId) return Forbid();
            }

            // 🔥 Can't flip back to "Available" while on an active trip (Confirmed or OnGoing).
            if (isAvailable)
            {
                var hasActiveTrip = await _context.Assignments
                    .Include(a => a.Booking)
                    .AnyAsync(a => a.VehicleId == id &&
                        (a.Booking.Status == BookingStatus.Confirmed || a.Booking.Status == BookingStatus.OnGoing));
                if (hasActiveTrip)
                    return BadRequest(new { message = "Can't mark this vehicle available while it has an active/on-going trip." });
            }

            vehicle.IsAvailable = isAvailable;
            await _context.SaveChangesAsync();
            return NoContent();
        }

        // DELETE: api/vehicles/5 (Admin only)
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var vehicle = await _context.Vehicles.FindAsync(id);
            if (vehicle == null) return NotFound(new { message = "Vehicle not found." });

            _context.Vehicles.Remove(vehicle);
            await _context.SaveChangesAsync();
            return NoContent();
        }

        // POST: api/vehicles/5/images (Admin only) — add image URL to gallery
        [HttpPost("{id}/images")]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<VehicleImage>> AddImage(int id, [FromBody] string imageUrl)
        {
            var vehicle = await _context.Vehicles.FindAsync(id);
            if (vehicle == null) return NotFound(new { message = "Vehicle not found." });

            var image = new VehicleImage
            {
                VehicleId = id,
                ImageUrl = imageUrl,
                IsCover = !await _context.VehicleImages.AnyAsync(vi => vi.VehicleId == id),
                UploadedAt = DateTime.UtcNow
            };

            _context.VehicleImages.Add(image);
            await _context.SaveChangesAsync();

            return Ok(image);
        }

        // 🔥 BUSINESS-SPECIFIC OPERATION: Distance-based vehicle pricing
        // POST: api/vehicles/distance-quote
        [HttpPost("distance-quote")]
        public async Task<IActionResult> GetDistanceQuote(
            DistanceQuoteRequestDto dto, [FromServices] IDistanceService distanceService)
        {
            var vehicle = await _context.Vehicles.FindAsync(dto.VehicleId);
            if (vehicle == null) return NotFound(new { message = "Vehicle not found." });

            var distanceKm = await distanceService.GetDistanceKmAsync(
                dto.StartLat, dto.StartLon, dto.EndLat, dto.EndLon);

            if (distanceKm == null)
                return Ok(new { available = false, message = "Distance calculation unavailable." });

            var totalCharge = vehicle.PricePerKm * (decimal)distanceKm.Value;

            return Ok(new DistanceQuoteResponseDto
            {
                DistanceKm = distanceKm.Value,
                PricePerKm = vehicle.PricePerKm,
                TotalVehicleCharge = Math.Round(totalCharge, 2)
            });
        }
    }
}
