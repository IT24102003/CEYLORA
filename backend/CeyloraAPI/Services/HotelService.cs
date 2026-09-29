using CeyloraAPI.Data;
using CeyloraAPI.DTOs;
using Microsoft.EntityFrameworkCore;

namespace CeyloraAPI.Services
{
    public class HotelService : IHotelService
    {
        private readonly AppDbContext _context;

        public HotelService(AppDbContext context)
        {
            _context = context;
        }

        public async Task<AvailabilityCheckResponseDto> CheckAvailabilityAsync(int hotelId, DateTime checkIn, DateTime checkOut, int roomsNeeded)
        {
            // Ensure DateTimes are UTC (PostgreSQL requires this)
            checkIn = DateTime.SpecifyKind(checkIn, DateTimeKind.Utc);
            checkOut = DateTime.SpecifyKind(checkOut, DateTimeKind.Utc);

            var hotel = await _context.Hotels.FindAsync(hotelId);

            if (hotel == null)
                return new AvailabilityCheckResponseDto { IsAvailable = false, Message = "Hotel not found." };

            if (checkOut <= checkIn)
                return new AvailabilityCheckResponseDto { IsAvailable = false, Message = "Check-out date must be after check-in date." };

            int nights = (checkOut - checkIn).Days;

            // Count overlapping bookings for the same hotel in the requested date range
            var overlappingBookings = await _context.HotelBookings
                .Where(hb => hb.HotelId == hotelId
                          && hb.Status != Models.HotelBookingStatus.Cancelled
                          && hb.CheckIn < checkOut
                          && hb.CheckOut > checkIn)
                .CountAsync();

            int roomsAvailableForDates = hotel.RoomsAvailable - overlappingBookings;
            bool isAvailable = roomsAvailableForDates >= roomsNeeded;

            return new AvailabilityCheckResponseDto
            {
                IsAvailable = isAvailable,
                RoomsAvailableForDates = Math.Max(roomsAvailableForDates, 0),
                TotalPrice = isAvailable ? hotel.PricePerNight * nights * roomsNeeded : 0,
                Nights = nights,
                Message = isAvailable
                    ? $"{roomsAvailableForDates} room(s) available for the selected dates."
                    : "Not enough rooms available for the selected dates."
            };
        }
    }
}