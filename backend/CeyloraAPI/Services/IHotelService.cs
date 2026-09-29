using CeyloraAPI.Models;
using CeyloraAPI.DTOs;

namespace CeyloraAPI.Services
{
    public interface IHotelService
    {
        Task<AvailabilityCheckResponseDto> CheckAvailabilityAsync(int hotelId, DateTime checkIn, DateTime checkOut, int roomsNeeded);
    }
}