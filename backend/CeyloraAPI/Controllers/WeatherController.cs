using CeyloraAPI.Services;
using Microsoft.AspNetCore.Mvc;

namespace CeyloraAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class WeatherController : ControllerBase
    {
        private readonly IWeatherService _weatherService;

        public WeatherController(IWeatherService weatherService)
        {
            _weatherService = weatherService;
        }

        // GET: api/weather/forecast?lat=7.29&lon=80.63
        [HttpGet("forecast")]
        public async Task<IActionResult> GetForecast([FromQuery] double lat, [FromQuery] double lon)
        {
            var result = await _weatherService.GetForecastAsync(lat, lon);
            if (result == null)
                return Ok(new { available = false, message = "Weather data unavailable." });

            return Ok(new
            {
                available = true,
                description = result.Description,
                temperature = result.TemperatureCelsius,
                icon = result.Icon,
                isRainy = result.IsRainy
            });
        }

        // GET: api/weather/forecast-day?lat=7.29&lon=80.63&daysFromNow=2
        [HttpGet("forecast-day")]
        public async Task<IActionResult> GetForecastForDay(
            [FromQuery] double lat, [FromQuery] double lon, [FromQuery] int daysFromNow)
        {
            var result = await _weatherService.GetForecastForDayAsync(lat, lon, daysFromNow);
            if (result == null)
                return Ok(new
                {
                    available = false,
                    message = "Forecast unavailable for this date (only up to 5 days ahead supported)."
                });

            return Ok(new
            {
                available = true,
                description = result.Description,
                temperature = result.TemperatureCelsius,
                icon = result.Icon,
                isRainy = result.IsRainy
            });
        }
    }
}