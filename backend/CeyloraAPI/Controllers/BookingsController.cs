using System.Security.Claims;
using CeyloraAPI.Data;
using CeyloraAPI.DTOs;
using CeyloraAPI.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CeyloraAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class BookingsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public BookingsController(AppDbContext context)
        {
            _context = context;
        }

        [HttpPost("calculate-cost")]
        [AllowAnonymous]
        public async Task<ActionResult<CalculateCostResponseDto>> CalculateCost(CalculateCostRequestDto dto)
        {
            decimal baseDestinationsFee = 0;
            decimal hotelFeePerNight = 0;
            decimal vehicleGuideRatePerDay = 5000; // Base estimate per day

            if (dto.PackageId.HasValue)
            {
                var pkg = await _context.Packages.FindAsync(dto.PackageId.Value);
                if (pkg != null)
                    baseDestinationsFee = pkg.BasePrice;
            }
            else if (dto.DestinationIds.Any())
            {
                // Custom destination selection: flat LKR 2,500 per destination entry
                baseDestinationsFee = dto.DestinationIds.Count * 2500m;
            }

            if (dto.HotelId.HasValue)
            {
                var hotel = await _context.Hotels.FindAsync(dto.HotelId.Value);
                if (hotel != null)
                    hotelFeePerNight = hotel.PricePerNight;
            }

            decimal hotelTotalFee = hotelFeePerNight * dto.HotelNights;
            decimal vehicleGuideFee = (dto.IncludeVehicle ? vehicleGuideRatePerDay : 0) + (dto.IncludeGuide ? 4000m : 0);
            vehicleGuideFee *= dto.DurationDays;

            decimal serviceFee = 2000m; // Flat platform service fee
            decimal totalCost = (baseDestinationsFee * dto.GroupSize) + hotelTotalFee + vehicleGuideFee + serviceFee;

            var summary = $"Destinations/Package ({baseDestinationsFee * dto.GroupSize} LKR) + Hotel Stay ({hotelTotalFee} LKR for {dto.HotelNights} nights) + Transport/Guide ({vehicleGuideFee} LKR) + Service Fee ({serviceFee} LKR)";

            return Ok(new CalculateCostResponseDto
            {
                BaseDestinationsFee = baseDestinationsFee * dto.GroupSize,
                HotelTotalFee = hotelTotalFee,
                VehicleGuideFee = vehicleGuideFee,
                ServiceFee = serviceFee,
                TotalCost = totalCost,
                Currency = "LKR",
                BreakdownSummary = summary
            });
        }

        [HttpPost("manual")]
        public async Task<ActionResult<BookingResponseDto>> CreateManualBooking(ManualBookingCreateDto dto)
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out int touristId))
            {
                // Fallback for development if claims are formatted differently
                touristId = await _context.Users.Where(u => u.Role == UserRole.Tourist).Select(u => u.Id).FirstOrDefaultAsync();
                if (touristId == 0) touristId = 1;
            }

            var package = await _context.Packages.FindAsync(dto.PackageId);
            if (package == null) return NotFound(new { message = "Package not found." });

            decimal hotelPrice = 0;
            if (dto.HotelId.HasValue)
            {
                var hotel = await _context.Hotels.FindAsync(dto.HotelId.Value);
                if (hotel != null) hotelPrice = hotel.PricePerNight;
            }

            int nights = (dto.CheckIn.HasValue && dto.CheckOut.HasValue) ? (dto.CheckOut.Value - dto.CheckIn.Value).Days : 1;
            if (nights <= 0) nights = 1;

            decimal totalPrice = (package.BasePrice * dto.GroupSize) + (hotelPrice * nights) + 2000m;

            var booking = new Booking
            {
                TouristId = touristId,
                PackageId = dto.PackageId,
                Status = BookingStatus.Pending,
                TotalPrice = totalPrice,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Bookings.Add(booking);
            await _context.SaveChangesAsync();

            if (dto.HotelId.HasValue && dto.CheckIn.HasValue && dto.CheckOut.HasValue)
            {
                _context.HotelBookings.Add(new HotelBooking
                {
                    BookingId = booking.Id,
                    HotelId = dto.HotelId.Value,
                    CheckIn = dto.CheckIn.Value,
                    CheckOut = dto.CheckOut.Value,
                    Status = HotelBookingStatus.Reserved,
                    CreatedAt = DateTime.UtcNow
                });
                await _context.SaveChangesAsync();
            }

            var tourist = await _context.Users.FindAsync(touristId);

            return Ok(new BookingResponseDto
            {
                Id = booking.Id,
                TouristId = booking.TouristId,
                TouristName = tourist?.Name ?? "Tourist",
                PackageId = booking.PackageId,
                PackageName = package.Name,
                Status = booking.Status,
                TotalPrice = booking.TotalPrice,
                CreatedAt = booking.CreatedAt
            });
        }

        [HttpGet("my-bookings")]
        public async Task<ActionResult<IEnumerable<BookingResponseDto>>> GetMyBookings()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            int.TryParse(userIdClaim, out int touristId);

            var query = _context.Bookings
                .Include(b => b.Package)
                .Include(b => b.Tourist)
                .AsQueryable();

            if (touristId > 0)
                query = query.Where(b => b.TouristId == touristId);

            var bookings = await query.Select(b => new BookingResponseDto
            {
                Id = b.Id,
                TouristId = b.TouristId,
                TouristName = b.Tourist.Name,
                PackageId = b.PackageId,
                PackageName = b.Package.Name,
                Status = b.Status,
                TotalPrice = b.TotalPrice,
                CreatedAt = b.CreatedAt
            }).ToListAsync();

            return Ok(bookings);
        }

        [HttpPatch("{id}/status")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> UpdateBookingStatus(int id, [FromBody] BookingStatus status)
        {
            var booking = await _context.Bookings.FindAsync(id);
            if (booking == null) return NotFound(new { message = "Booking not found." });

            booking.Status = status;
            booking.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return Ok(new { message = $"Booking status updated to {status}." });
        }
    }
}
