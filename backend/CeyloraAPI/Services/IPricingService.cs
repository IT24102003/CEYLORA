using CeyloraAPI.Models;
using CeyloraAPI.DTOs;

namespace CeyloraAPI.Services
{
    public interface IPricingService
    {
        PriceQuoteResponseDto CalculatePrice(Package package, int groupSize, DateTime travelDate);
    }
}