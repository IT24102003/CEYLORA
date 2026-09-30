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
                return null;
            }
        }

        // Free-tier forecast endpoint supports up to 5 days ahead, in 3-hour steps.
        public async Task<WeatherResult?> GetForecastForDayAsync(double latitude, double longitude, int daysFromNow)
        {
            if (string.IsNullOrEmpty(_apiKey)) return null;
            if (daysFromNow < 0 || daysFromNow > 5) return null;

            var url = $"https://api.openweathermap.org/data/2.5/forecast" +
                       $"?lat={latitude}&lon={longitude}&appid={_apiKey}&units=metric";

            try
            {
                var response = await _httpClient.GetAsync(url);
                if (!response.IsSuccessStatusCode) return null;

                var json = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(json);
                var list = doc.RootElement.GetProperty("list");

                var targetDate = DateTime.UtcNow.Date.AddDays(daysFromNow);
                JsonElement? bestMatch = null;
                int bestDiffHours = int.MaxValue;

                foreach (var item in list.EnumerateArray())
                {
                    var dtTxt = item.GetProperty("dt_txt").GetString();
                    if (dtTxt == null) continue;
                    if (!DateTime.TryParse(dtTxt, out var itemDateTime)) continue;
                    if (itemDateTime.Date != targetDate) continue;

                    var diff = Math.Abs(itemDateTime.Hour - 12); // prefer entry closest to midday
                    if (diff < bestDiffHours)
                    {
                        bestDiffHours = diff;
                        bestMatch = item;
                    }
                }

                if (bestMatch == null) return null;

                var weatherArray = bestMatch.Value.GetProperty("weather");
                var description = weatherArray[0].GetProperty("description").GetString() ?? "";
                var icon = weatherArray[0].GetProperty("icon").GetString() ?? "";
                var temp = bestMatch.Value.GetProperty("main").GetProperty("temp").GetDouble();

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
                return null;
            }
        }
    }
}