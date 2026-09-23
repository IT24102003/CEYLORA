using CeyloraAPI.Models;

namespace CeyloraAPI.DTOs
{
    public class StartWorkflowDto
    {
        public string Objective { get; set; } = string.Empty;
        public int PackageId { get; set; }
        public decimal BudgetCap { get; set; }
        public int GroupSize { get; set; } = 1;
        public int DurationDays { get; set; } = 3;
    }

    public class WorkflowStatusDto
    {
        public int WorkflowId { get; set; }
        public int BookingId { get; set; }
        public string Objective { get; set; } = string.Empty;
        public string? PlanJson { get; set; }
        public WorkflowStatus Status { get; set; }
        public ApprovalStatus ApprovalStatus { get; set; }
        public DateTime CreatedAt { get; set; }
        public List<AgentExecutionLogDto> Logs { get; set; } = new();
    }

    public class AgentExecutionLogDto
    {
        public int Id { get; set; }
        public string AgentName { get; set; } = string.Empty;
        public string StepName { get; set; } = string.Empty;
        public string? Input { get; set; }
        public string? Output { get; set; }
        public string? ValidationResult { get; set; }
        public DateTime Timestamp { get; set; }
    }

    public class ApprovalActionDto
    {
        public string Action { get; set; } = "Approve"; // "Approve", "Reject", "Revise"
        public string? Comments { get; set; }
    }
}
