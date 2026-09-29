using System.Text.Json;

namespace CeyloraAPI.Services
{
    public class DistanceService : IDistanceService
    {
        private readonly HttpClient _httpClient;
        private readonly string _apiKey;

        public DistanceService(HttpClient httpClient, IConfiguration config)
        {
            _httpClient = httpClient;
            _apiKey = config["ExternalServices:OpenRouteServiceApiKey"] ?? "";
        }

        public async Task<double?> GetDistanceKmAsync(double startLat, double startLon, double endLat, double endLon)
        {
            if (string.IsNullOrEmpty(_apiKey)) return null;

            var url = "https://api.openrouteservice.org/v2/directions/driving-car";
            var body = new
            {
                coordinates = new[]
                {
                    new[] { startLon, startLat },
                    new[] { endLon, endLat }
                }
            };

            var request = new HttpRequestMessage(HttpMethod.Post, url);
            request.Headers.TryAddWithoutValidation("Authorization", _apiKey);
            request.Content = new StringContent(
                JsonSerializer.Serialize(body), System.Text.Encoding.UTF8, "application/json");

            try
            {
                var response = await _httpClient.SendAsync(request);
                if (!response.IsSuccessStatusCode) return null;

                var json = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(json);
                var distanceMeters = doc.RootElement
                    .GetProperty("routes")[0]
                    .GetProperty("summary")
                    .GetProperty("distance")
                    .GetDouble();

                return Math.Round(distanceMeters / 1000, 2);
            }
            catch
            {
                return null;
            }
        }
    }
}