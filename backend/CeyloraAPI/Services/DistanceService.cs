using System.Text.Json;

namespace CeyloraAPI.Services
{
    public class DistanceService : IDistanceService
    {
        private readonly HttpClient _httpClient;
        private readonly string _apiKey;
        private readonly ILogger<DistanceService> _logger;

        public DistanceService(HttpClient httpClient, IConfiguration config, ILogger<DistanceService> logger)
        {
            _httpClient = httpClient;
            _apiKey = config["ExternalServices:OpenRouteServiceApiKey"] ?? "";
            _logger = logger;
        }

        public async Task<double?> GetDistanceKmAsync(double startLat, double startLon, double endLat, double endLon)
        {
            if (string.IsNullOrEmpty(_apiKey))
            {
                _logger.LogWarning("DistanceService: OpenRouteServiceApiKey is not configured — skipping distance lookup.");
                return null;
            }

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
            // 🔥 OpenRouteService expects the raw API key in the Authorization header —
            // no "Bearer " prefix — which this already did correctly.
            request.Headers.TryAddWithoutValidation("Authorization", _apiKey);
            request.Content = new StringContent(
                JsonSerializer.Serialize(body), System.Text.Encoding.UTF8, "application/json");

            try
            {
                var response = await _httpClient.SendAsync(request);
                var json = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                {
                    // 🔥 This used to fail completely silently — every failure
                    // (bad/expired key, over quota, no route found between the two
                    // points, ORS being down) looked identical to the tourist: a
                    // permanently-zero "Distance unavailable" with nothing in the
                    // logs to explain why. Now the real reason lands in the
                    // backend console so it's actually debuggable.
                    _logger.LogWarning(
                        "DistanceService: OpenRouteService returned {StatusCode} for ({StartLat},{StartLon}) -> ({EndLat},{EndLon}): {Body}",
                        (int)response.StatusCode, startLat, startLon, endLat, endLon, json);
                    return null;
                }

                using var doc = JsonDocument.Parse(json);
                var distanceMeters = doc.RootElement
                    .GetProperty("routes")[0]
                    .GetProperty("summary")
                    .GetProperty("distance")
                    .GetDouble();

                return Math.Round(distanceMeters / 1000, 2);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex,
                    "DistanceService: failed to get distance for ({StartLat},{StartLon}) -> ({EndLat},{EndLon})",
                    startLat, startLon, endLat, endLon);
                return null;
            }
        }
    }
}