using System.Text;
using System.Text.Json;

namespace CeyloraAPI.Services
{
    public class AgenticAIClient : IAgenticAIClient
    {
        private readonly HttpClient _httpClient;
        private readonly string _baseUrl;

        public AgenticAIClient(HttpClient httpClient, IConfiguration config)
        {
            _httpClient = httpClient;
            _baseUrl = config["AgenticAI:BaseUrl"] ?? "http://localhost:8001";
        }

        public async Task<string> RunWorkflowAsync(string objective, int? bookingId)
        {
            var payload = new { objective, booking_id = bookingId };
            var json = JsonSerializer.Serialize(payload);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync($"{_baseUrl}/agent/run", content);
            response.EnsureSuccessStatusCode();

            return await response.Content.ReadAsStringAsync();
        }

        public async Task<string> GetWorkflowStatusAsync(string workflowId)
        {
            var response = await _httpClient.GetAsync($"{_baseUrl}/agent/status/{workflowId}");
            response.EnsureSuccessStatusCode();

            return await response.Content.ReadAsStringAsync();
        }
    }
}