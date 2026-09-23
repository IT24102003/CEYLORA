namespace CeyloraAPI.Models
{
    public enum WorkflowStatus { Running, Completed, Failed }

    public class AgentWorkflow
    {
        public int Id { get; set; }
        public int BookingId { get; set; }
        public Booking Booking { get; set; } = null!;
        public string Objective { get; set; } = string.Empty;
        public string? PlanJson { get; set; }
        public WorkflowStatus Status { get; set; } = WorkflowStatus.Running;
        public ApprovalStatus ApprovalStatus { get; set; } = ApprovalStatus.PendingApproval;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        public ICollection<AgentExecutionLog> Logs { get; set; } = new List<AgentExecutionLog>();
    }
}