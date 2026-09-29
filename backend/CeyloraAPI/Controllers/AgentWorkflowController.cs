using CeyloraAPI.Data;
using CeyloraAPI.DTOs;
using CeyloraAPI.Models;
using CeyloraAPI.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace CeyloraAPI.Controllers
{
    [ApiController]
    [Route("api/agent-workflows")]
    [Authorize]
    public class AgentWorkflowController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IAgenticAIClient _aiClient;

        public AgentWorkflowController(AppDbContext context, IAgenticAIClient aiClient)
        {
            _context = context;
            _aiClient = aiClient;
        }

        // POST: api/agent-workflows/start
        [HttpPost("start")]
        public async Task<IActionResult> StartWorkflow(StartWorkflowDto dto)
        {
            if (dto.BookingId.HasValue)
            {
                var bookingExists = await _context.Bookings.AnyAsync(b => b.Id == dto.BookingId.Value);
                if (!bookingExists) return NotFound(new { message = "Booking not found." });
            }

            // Calls the internal Python service (never called directly by React/Flutter)
            var rawResult = await _aiClient.RunWorkflowAsync(dto.Objective, dto.BookingId);

            string pythonWorkflowId = "";
            string statusFromPython = "";
            bool? validationPassed = null;

            using (var doc = JsonDocument.Parse(rawResult))
            {
                var root = doc.RootElement;
                pythonWorkflowId = root.GetProperty("workflow_id").GetString() ?? "";
                statusFromPython = root.GetProperty("status").GetString() ?? "";

                if (root.TryGetProperty("validation_passed", out var vp) && vp.ValueKind != JsonValueKind.Null)
                    validationPassed = vp.GetBoolean();

                var workflow = new AgentWorkflow
                {
                    BookingId = dto.BookingId, // nullable now — no booking required to explore a plan
                    Objective = dto.Objective,
                    PlanJson = rawResult,
                    Status = statusFromPython == "completed" ? WorkflowStatus.Completed : WorkflowStatus.Failed,
                    ApprovalStatus = ApprovalStatus.PendingApproval,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };

                _context.AgentWorkflows.Add(workflow);
                await _context.SaveChangesAsync();

                // Store execution log entries for auditability (spec requirement)
                if (root.TryGetProperty("execution_log", out var logsElement))
                {
                    foreach (var logEntry in logsElement.EnumerateArray())
                    {
                        _context.AgentExecutionLogs.Add(new AgentExecutionLog
                        {
                            WorkflowId = workflow.Id,
                            AgentName = logEntry.GetProperty("agent_name").GetString() ?? "",
                            StepName = logEntry.GetProperty("step_name").GetString() ?? "",
                            Output = logEntry.TryGetProperty("output", out var outEl) ? outEl.GetString() : null,
                            Timestamp = DateTime.UtcNow
                        });
                    }
                    await _context.SaveChangesAsync();
                }

                return Ok(new
                {
                    workflowId = workflow.Id,
                    pythonWorkflowId,
                    status = workflow.Status.ToString(),
                    validationPassed,
                    fullResultJson = rawResult
                });
            }
        }

        // GET: api/agent-workflows/{id}
        [HttpGet("{id}")]
        public async Task<IActionResult> GetWorkflow(int id)
        {
            var workflow = await _context.AgentWorkflows
                .Include(w => w.Logs)
                .FirstOrDefaultAsync(w => w.Id == id);

            if (workflow == null) return NotFound(new { message = "Workflow not found." });
            return Ok(workflow);
        }

        // GET: api/agent-workflows/pending-approval (Admin monitoring queue)
        [HttpGet("pending-approval")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetPendingApproval()
        {
            var pending = await _context.AgentWorkflows
                .Include(w => w.Logs)
                .Where(w => w.ApprovalStatus == ApprovalStatus.PendingApproval)
                .ToListAsync();

            return Ok(pending);
        }

        // PUT: api/agent-workflows/{id}/approve (high-impact action approval — spec requirement)
        [HttpPut("{id}/approve")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> UpdateApproval(int id, WorkflowApprovalDto dto)
        {
            var workflow = await _context.AgentWorkflows.FindAsync(id);
            if (workflow == null) return NotFound(new { message = "Workflow not found." });

            if (!Enum.TryParse<ApprovalStatus>(dto.ApprovalStatus, true, out var newStatus))
                return BadRequest(new { message = "Invalid approval status." });

            workflow.ApprovalStatus = newStatus;
            workflow.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return NoContent();
        }
    }
}