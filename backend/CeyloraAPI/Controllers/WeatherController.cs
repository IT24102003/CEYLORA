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
    }
}