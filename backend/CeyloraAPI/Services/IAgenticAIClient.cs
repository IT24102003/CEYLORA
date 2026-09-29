namespace CeyloraAPI.Services
{
    public interface IAgenticAIClient
    {
        Task<string> RunWorkflowAsync(string objective, int? bookingId);
        Task<string> GetWorkflowStatusAsync(string workflowId);
    }
}