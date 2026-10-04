using CeyloraAPI.Services;
using Xunit;

namespace CeyloraAPI.Tests.Services
{
    public class VehiclePricingTests
    {
        [Theory]
        [InlineData("Car", 120)]
        [InlineData("Van", 180)]
        [InlineData("Bus", 280)]
        public void GetPricePerKm_KnownType_ReturnsFixedRate(string type, decimal expected)
        {
            Assert.Equal(expected, VehiclePricing.GetPricePerKm(type));
        }

        [Theory]
        [InlineData("car")]
        [InlineData("CAR")]
        [InlineData(" Car ")]
        public void GetPricePerKm_IsCaseAndWhitespaceInsensitive(string type)
        {
            Assert.Equal(VehiclePricing.CarPerKm, VehiclePricing.GetPricePerKm(type));
        }

        [Theory]
        [InlineData(null)]
        [InlineData("")]
        [InlineData("Helicopter")]
        public void GetPricePerKm_UnknownOrMissingType_DefaultsToCarRate(string? type)
        {
            Assert.Equal(VehiclePricing.CarPerKm, VehiclePricing.GetPricePerKm(type));
        }
    }
}
