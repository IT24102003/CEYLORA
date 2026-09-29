using CeyloraAPI.DTOs;

namespace CeyloraAPI.Services
{
    public interface IBookingService
    {
        Task<(bool hasConflict, string message)> CheckAssignmentConflictAsync(int? guideId, int? vehicleId, DateTime travelDate);
    }
}