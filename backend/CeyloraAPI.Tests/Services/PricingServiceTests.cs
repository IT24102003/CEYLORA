using CeyloraAPI.Models;
using CeyloraAPI.Services;
using Xunit;

namespace CeyloraAPI.Tests.Services
{
    public class PricingServiceTests
    {
        private readonly PricingService _service = new();

        private static Package MakePackage(decimal basePrice = 10000m) =>
            new Package { Id = 1, Name = "Test Package", BasePrice = basePrice };

        [Theory]
        [InlineData(12)] // December
        [InlineData(1)]  // January
        [InlineData(2)]  // February
        [InlineData(7)]  // July
        [InlineData(8)]  // August
        public void CalculatePrice_PeakSeasonMonth_Applies25PercentMultiplier(int month)
        {
            var package = MakePackage(10000m);
            var travelDate = new DateTime(2026, month, 15);

            var result = _service.CalculatePrice(package, groupSize: 1, travelDate);

            Assert.Equal(1.25m, result.SeasonMultiplier);
            Assert.Equal(12500m, result.FinalPricePerPerson);
        }

        [Theory]
        [InlineData(3)]
        [InlineData(4)]
        [InlineData(5)]
        [InlineData(6)]
        [InlineData(9)]
        [InlineData(10)]
        [InlineData(11)]
        public void CalculatePrice_OffPeakSeasonMonth_NoMultiplierApplied(int month)
        {
            var package = MakePackage(10000m);
            var travelDate = new DateTime(2026, month, 15);

            var result = _service.CalculatePrice(package, groupSize: 1, travelDate);

            Assert.Equal(1.0m, result.SeasonMultiplier);
            Assert.Equal(10000m, result.FinalPricePerPerson);
        }

        [Fact]
        public void CalculatePrice_GroupSizeBelow3_NoGroupDiscount()
        {
            var package = MakePackage(10000m);
            var travelDate = new DateTime(2026, 5, 1); // off-peak

            var result = _service.CalculatePrice(package, groupSize: 2, travelDate);

            Assert.Equal(0m, result.GroupDiscount);
            Assert.Equal(10000m, result.FinalPricePerPerson);
            Assert.Equal(20000m, result.TotalPrice);
        }

        [Fact]
        public void CalculatePrice_GroupSize3_Applies5PercentDiscount()
        {
            var package = MakePackage(10000m);
            var travelDate = new DateTime(2026, 5, 1);

            var result = _service.CalculatePrice(package, groupSize: 3, travelDate);

            Assert.Equal(0.05m, result.GroupDiscount);
            Assert.Equal(9500m, result.FinalPricePerPerson);
            Assert.Equal(28500m, result.TotalPrice);
        }

        [Fact]
        public void CalculatePrice_GroupSize6_Applies10PercentDiscount()
        {
            var package = MakePackage(10000m);
            var travelDate = new DateTime(2026, 5, 1);

            var result = _service.CalculatePrice(package, groupSize: 6, travelDate);

            Assert.Equal(0.10m, result.GroupDiscount);
            Assert.Equal(9000m, result.FinalPricePerPerson);
        }

        [Fact]
        public void CalculatePrice_GroupSize10OrMore_Applies15PercentDiscount()
        {
            var package = MakePackage(10000m);
            var travelDate = new DateTime(2026, 5, 1);

            var result = _service.CalculatePrice(package, groupSize: 10, travelDate);

            Assert.Equal(0.15m, result.GroupDiscount);
            Assert.Equal(8500m, result.FinalPricePerPerson);
            Assert.Equal(85000m, result.TotalPrice);
        }

        [Fact]
        public void CalculatePrice_PeakSeasonAndGroupDiscount_BothApplyTogether()
        {
            // Peak month (Dec) + group of 10 -> multiplier 1.25, discount 0.15
            var package = MakePackage(10000m);
            var travelDate = new DateTime(2026, 12, 20);

            var result = _service.CalculatePrice(package, groupSize: 10, travelDate);

            Assert.Equal(1.25m, result.SeasonMultiplier);
            Assert.Equal(0.15m, result.GroupDiscount);
            // base * 1.25 * (1 - 0.15) = 10000 * 1.25 * 0.85 = 10625
            Assert.Equal(10625m, result.FinalPricePerPerson);
            Assert.Contains("Peak season", result.PricingNote);
            Assert.Contains("Group discount", result.PricingNote);
        }
    }
}
