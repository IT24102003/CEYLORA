using System.Text.Json;

namespace CeyloraAPI.Services
{
    public class WeatherService : IWeatherService
    {
        private readonly HttpClient _httpClient;
        private readonly string _apiKey;

        public WeatherService(HttpClient httpClient, IConfiguration config)
        {
            _httpClient = httpClient;
            _apiKey = config["ExternalServices:OpenWeatherApiKey"] ?? "";
        }

        public async Task<WeatherResult?> GetForecastAsync(double latitude, double longitude)
        {
            if (string.IsNullOrEmpty(_apiKey)) return null;

            var url = $"https://api.openweathermap.org/data/2.5/weather" +
                       $"?lat={latitude}&lon={longitude}&appid={_apiKey}&units=metric";

            try
            {
                var response = await _httpClient.GetAsync(url);
                if (!response.IsSuccessStatusCode) return null;

                var json = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;

                var weatherArray = root.GetProperty("weather");
                var description = weatherArray[0].GetProperty("description").GetString() ?? "";
                var icon = weatherArray[0].GetProperty("icon").GetString() ?? "";
                var temp = root.GetProperty("main").GetProperty("temp").GetDouble();

                return new WeatherResult
                {
                    Description = description,
                    TemperatureCelsius = temp,
                    Icon = icon,
                    IsRainy = description.Contains("rain", StringComparison.OrdinalIgnoreCase)
                };
            }
            catch
            {
                return null; // safe failure — don't crash the request if weather API is down
            }
        }
    }
}