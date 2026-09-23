using CeyloraAPI.Models;
using CeyloraAPI.DTOs;

namespace CeyloraAPI.Services
{
    public class PricingService : IPricingService
    {
        public PriceQuoteResponseDto CalculatePrice(Package package, int groupSize, DateTime travelDate)
        {
            // Season multiplier: Dec-Jan-Feb + Jul-Aug = peak season (Sri Lanka tourist peak)
            var peakMonths = new[] { 12, 1, 2, 7, 8 };
            decimal seasonMultiplier = peakMonths.Contains(travelDate.Month) ? 1.25m : 1.0m;

            // Group discount: bigger groups get a discount per person
            decimal groupDiscount = groupSize switch
            {
                >= 10 => 0.15m,
                >= 6 => 0.10m,
                >= 3 => 0.05m,
                _ => 0m
            };

            decimal adjustedBase = package.BasePrice * seasonMultiplier;
            decimal finalPerPerson = adjustedBase * (1 - groupDiscount);
            decimal total = finalPerPerson * groupSize;

            string note = seasonMultiplier > 1
                ? $"Peak season pricing applied (+{(seasonMultiplier - 1) * 100}%). "
                : "Off-peak season pricing. ";
            note += groupDiscount > 0
                ? $"Group discount applied (-{groupDiscount * 100}%)."
                : "No group discount (minimum 3 people required).";

            return new PriceQuoteResponseDto
            {
                BasePrice = package.BasePrice,
                SeasonMultiplier = seasonMultiplier,
                GroupDiscount = groupDiscount,
                FinalPricePerPerson = Math.Round(finalPerPerson, 2),
                TotalPrice = Math.Round(total, 2),
                PricingNote = note
            };
        }
    }
}