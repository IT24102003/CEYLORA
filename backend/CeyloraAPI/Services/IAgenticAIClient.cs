namespace CeyloraAPI.Services
{
    public interface IAgenticAIClient
    {
        Task<string> RunWorkflowAsync(string objective, int? bookingId, string? touristCountry = null);
        Task<string> GetWorkflowStatusAsync(string workflowId);
    }
}