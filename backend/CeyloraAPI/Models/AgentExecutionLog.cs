namespace CeyloraAPI.Models
{
    public class AgentExecutionLog
    {
        public int Id { get; set; }
        public int WorkflowId { get; set; }
        public AgentWorkflow Workflow { get; set; } = null!;
        public string AgentName { get; set; } = string.Empty;
        public string StepName { get; set; } = string.Empty;
        public string? Input { get; set; }
        public string? Output { get; set; }
        public string? ValidationResult { get; set; }
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    }
}