namespace CeyloraAPI.DTOs
{
    public class StartWorkflowDto
    {
        public string Objective { get; set; } = string.Empty;
        public int? BookingId { get; set; }
    }

    public class WorkflowApprovalDto
    {
        public string ApprovalStatus { get; set; } = string.Empty; // Approved, Rejected, RevisionRequested
    }
}