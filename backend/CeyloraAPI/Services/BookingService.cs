using CeyloraAPI.Data;
using Microsoft.EntityFrameworkCore;

namespace CeyloraAPI.Services
{
    public class BookingService : IBookingService
    {
        private readonly AppDbContext _context;

        public BookingService(AppDbContext context)
        {
            _context = context;
        }

        // Checks if a guide/vehicle is already assigned to another booking on the same date
        public async Task<(bool hasConflict, string message)> CheckAssignmentConflictAsync(int? guideId, int? vehicleId, DateTime travelDate)
        {
            var dateOnly = travelDate.Date;

            if (guideId.HasValue)
            {
                var guideConflict = await _context.Assignments
                    .Include(a => a.Booking)
                    .Where(a => a.GuideId == guideId
                             && a.Status != Models.AssignmentStatus.Cancelled
                             && a.Booking.CreatedAt.Date == dateOnly) // simplified: same travel date via booking
                    .AnyAsync();

                if (guideConflict)
                    return (true, "Selected guide is already assigned to another trip on this date.");
            }

            if (vehicleId.HasValue)
            {
                var vehicleConflict = await _context.Assignments
                    .Include(a => a.Booking)
                    .Where(a => a.VehicleId == vehicleId
                             && a.Status != Models.AssignmentStatus.Cancelled
                             && a.Booking.CreatedAt.Date == dateOnly)
                    .AnyAsync();

                if (vehicleConflict)
                    return (true, "Selected vehicle is already assigned to another trip on this date.");
            }

            return (false, "No conflicts found.");
        }
    }
}