using CeyloraAPI.Data; 
using CeyloraAPI.DTOs; 
using CeyloraAPI.Models; 
using Microsoft.EntityFrameworkCore; 
  
namespace CeyloraAPI.Services 
{ 
    public class AssignmentService : IAssignmentService 
    { 
        private readonly AppDbContext _context; 
  
        public AssignmentService(AppDbContext context) 
        { 
            _context = context; 
        } 
  
        public async Task<AssignmentResultDto> AutoMatchAsync(int bookingId, string region, string? 
preferredLanguage) 
        { 
            var booking = await _context.Bookings.FindAsync(bookingId); 
            if (booking == null) 
                return new AssignmentResultDto { Success = false, Message = "Booking not found." }; 
  
            // Rank available guides in the region: language match first, then rating 
            var guideQuery = _context.Guides 
                .Where(g => g.IsAvailable && g.Region.ToLower() == region.ToLower()); 
  
            var guide = await guideQuery 
                .OrderByDescending(g => preferredLanguage != null 
                    && g.Languages != null 
                    && g.Languages.ToLower().Contains(preferredLanguage.ToLower())) 
                .ThenByDescending(g => g.Rating) 
                .FirstOrDefaultAsync(); 
  
            // Pick the first available vehicle in the same region 
            var vehicle = await _context.Vehicles 
                .Where(v => v.IsAvailable && v.Region.ToLower() == region.ToLower()) 
                .FirstOrDefaultAsync(); 
  
            if (guide == null && vehicle == null) 
                return new AssignmentResultDto 
                { 
                    Success = false, 
                    Message = "No available guide or vehicle found in this region." 
                }; 
  
            var assignment = new Assignment 
            { 
                BookingId = bookingId, 
                GuideId = guide?.Id, 
                VehicleId = vehicle?.Id, 
                Status = AssignmentStatus.Proposed, 
                AssignedAt = DateTime.UtcNow 
            }; 
  
            _context.Assignments.Add(assignment); 
  
            // Mark matched resources as temporarily unavailable 
            if (guide != null) guide.IsAvailable = false; 
            if (vehicle != null) vehicle.IsAvailable = false; 
  
            await _context.SaveChangesAsync(); 
  
            var guideUser = guide != null 
                ? await _context.Users.FindAsync(guide.UserId) 
                : null; 
  
            return new AssignmentResultDto 
            { 
                AssignmentId = assignment.Id, 
                GuideId = guide?.Id, 
                GuideName = guideUser?.Name, 
                VehicleId = vehicle?.Id, 
                VehicleType = vehicle?.Type, 
                Success = true, 
                Message = "Guide/vehicle matched and proposed for this booking." 
            }; 
        } 
    } 
} 