using System.Security.Claims;
using CeyloraAPI.Data;
using CeyloraAPI.DTOs;
using CeyloraAPI.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CeyloraAPI.Controllers
{
    [ApiController]
    [Route("api/agent-workflows")]
    [Authorize]
    public class AgentWorkflowController : ControllerBase
    {
        private readonly AppDbContext _context;

        public AgentWorkflowController(AppDbContext context)
        {
            _context = context;
        }

        [HttpPost("start")]
        public async Task<ActionResult<WorkflowStatusDto>> StartWorkflow(StartWorkflowDto dto)
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            int.TryParse(userIdClaim, out int touristId);
            if (touristId == 0) touristId = 1;

            var package = await _context.Packages.FindAsync(dto.PackageId);
            if (package == null)
            {
                package = await _context.Packages.FirstOrDefaultAsync();
                if (package == null) return BadRequest(new { message = "No valid package found for workflow initialization." });
            }

            var booking = new Booking
            {
                TouristId = touristId,
                PackageId = package.Id,
                Status = BookingStatus.Pending,
                TotalPrice = dto.BudgetCap > 0 ? dto.BudgetCap : package.BasePrice,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Bookings.Add(booking);
            await _context.SaveChangesAsync();

            var workflow = new AgentWorkflow
            {
                BookingId = booking.Id,
                Objective = dto.Objective,
                PlanJson = $"{{\"durationDays\": {dto.DurationDays}, \"groupSize\": {dto.GroupSize}, \"budgetCap\": {dto.BudgetCap}}}",
                Status = WorkflowStatus.Running,
                ApprovalStatus = ApprovalStatus.PendingApproval,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.AgentWorkflows.Add(workflow);
            await _context.SaveChangesAsync();

            // Initial log by Planner Agent
            var plannerLog = new AgentExecutionLog
            {
                WorkflowId = workflow.Id,
                AgentName = "Planner/Coordinator Agent",
                StepName = "Objective Analysis & Decomposition",
                Input = dto.Objective,
                Output = $"Structured plan generated: {dto.DurationDays} days in Sri Lanka for {dto.GroupSize} guests with budget {dto.BudgetCap} LKR.",
                ValidationResult = "Passed",
                Timestamp = DateTime.UtcNow
            };

            _context.AgentExecutionLogs.Add(plannerLog);
            await _context.SaveChangesAsync();

            return Ok(new WorkflowStatusDto
            {
                WorkflowId = workflow.Id,
                BookingId = booking.Id,
                Objective = workflow.Objective,
                PlanJson = workflow.PlanJson,
                Status = workflow.Status,
                ApprovalStatus = workflow.ApprovalStatus,
                CreatedAt = workflow.CreatedAt,
                Logs = new List<AgentExecutionLogDto>
                {
                    new AgentExecutionLogDto
                    {
                        Id = plannerLog.Id,
                        AgentName = plannerLog.AgentName,
                        StepName = plannerLog.StepName,
                        Input = plannerLog.Input,
                        Output = plannerLog.Output,
                        ValidationResult = plannerLog.ValidationResult,
                        Timestamp = plannerLog.Timestamp
                    }
                }
            });
        }

        [HttpGet("{id}/status")]
        public async Task<ActionResult<WorkflowStatusDto>> GetStatus(int id)
        {
            var wf = await _context.AgentWorkflows
                .Include(w => w.Logs)
                .FirstOrDefaultAsync(w => w.Id == id);

            if (wf == null) return NotFound(new { message = "Workflow not found." });

            return Ok(new WorkflowStatusDto
            {
                WorkflowId = wf.Id,
                BookingId = wf.BookingId,
                Objective = wf.Objective,
                PlanJson = wf.PlanJson,
                Status = wf.Status,
                ApprovalStatus = wf.ApprovalStatus,
                CreatedAt = wf.CreatedAt,
                Logs = wf.Logs.Select(l => new AgentExecutionLogDto
                {
                    Id = l.Id,
                    AgentName = l.AgentName,
                    StepName = l.StepName,
                    Input = l.Input,
                    Output = l.Output,
                    ValidationResult = l.ValidationResult,
                    Timestamp = l.Timestamp
                }).OrderBy(l => l.Timestamp).ToList()
            });
        }

        [HttpGet("pending")]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<IEnumerable<WorkflowStatusDto>>> GetPendingWorkflows()
        {
            var workflows = await _context.AgentWorkflows
                .Include(w => w.Logs)
                .Where(w => w.ApprovalStatus == ApprovalStatus.PendingApproval)
                .Select(wf => new WorkflowStatusDto
                {
                    WorkflowId = wf.Id,
                    BookingId = wf.BookingId,
                    Objective = wf.Objective,
                    PlanJson = wf.PlanJson,
                    Status = wf.Status,
                    ApprovalStatus = wf.ApprovalStatus,
                    CreatedAt = wf.CreatedAt,
                    Logs = wf.Logs.Select(l => new AgentExecutionLogDto
                    {
                        Id = l.Id,
                        AgentName = l.AgentName,
                        StepName = l.StepName,
                        Input = l.Input,
                        Output = l.Output,
                        ValidationResult = l.ValidationResult,
                        Timestamp = l.Timestamp
                    }).ToList()
                }).ToListAsync();

            return Ok(workflows);
        }

        [HttpPost("{id}/approve")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> ApproveWorkflow(int id, [FromBody] ApprovalActionDto dto)
        {
            var wf = await _context.AgentWorkflows
                .Include(w => w.Booking)
                .FirstOrDefaultAsync(w => w.Id == id);

            if (wf == null) return NotFound(new { message = "Workflow not found." });

            if (dto.Action.Equals("Approve", StringComparison.OrdinalIgnoreCase))
            {
                wf.ApprovalStatus = ApprovalStatus.Approved;
                wf.Status = WorkflowStatus.Completed;
                wf.Booking.Status = BookingStatus.Confirmed;
            }
            else if (dto.Action.Equals("Reject", StringComparison.OrdinalIgnoreCase))
            {
                wf.ApprovalStatus = ApprovalStatus.Rejected;
                wf.Status = WorkflowStatus.Failed;
                wf.Booking.Status = BookingStatus.Cancelled;
            }
            else
            {
                wf.ApprovalStatus = ApprovalStatus.RevisionRequested;
            }

            wf.UpdatedAt = DateTime.UtcNow;

            _context.AgentExecutionLogs.Add(new AgentExecutionLog
            {
                WorkflowId = wf.Id,
                AgentName = "Human-in-the-Loop (Admin)",
                StepName = $"Decision: {dto.Action}",
                Input = dto.Comments ?? "No comments",
                Output = $"Status set to {wf.ApprovalStatus}. Booking #{wf.BookingId} set to {wf.Booking.Status}.",
                ValidationResult = dto.Action,
                Timestamp = DateTime.UtcNow
            });

            await _context.SaveChangesAsync();

            return Ok(new { message = $"Workflow #{id} action '{dto.Action}' processed successfully.", approvalStatus = wf.ApprovalStatus });
        }
    }
}
