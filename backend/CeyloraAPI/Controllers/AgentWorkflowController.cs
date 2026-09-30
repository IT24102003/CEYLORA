using CeyloraAPI.Data;
using CeyloraAPI.DTOs;
using CeyloraAPI.Models;
using CeyloraAPI.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
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
        private readonly INotificationService _notificationService;

        public AgentWorkflowController(AppDbContext context, IAgenticAIClient aiClient, INotificationService notificationService)
        {
            _context = context;
            _aiClient = aiClient;
            _notificationService = notificationService;
        }

        private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        // POST: api/agent-workflows/start
        [HttpPost("start")]
        public async Task<IActionResult> StartWorkflow(StartWorkflowDto dto)
        {
            if (dto.BookingId.HasValue)
            {
                var bookingExists = await _context.Bookings.AnyAsync(b => b.Id == dto.BookingId.Value);
                if (!bookingExists) return NotFound(new { message = "Booking not found." });
            }

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
                    BookingId = dto.BookingId,
                    Objective = dto.Objective,
                    PlanJson = rawResult,
                    Status = statusFromPython == "completed" ? WorkflowStatus.Completed : WorkflowStatus.Failed,
                    ApprovalStatus = ApprovalStatus.PendingApproval,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };

                _context.AgentWorkflows.Add(workflow);
                await _context.SaveChangesAsync();

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

        // POST: api/agent-workflows/preview
        // Calls the AI service ONLY — does not persist anything. Used so the tourist can
        // review the AI's suggestion and customize it before submitting for admin approval.
        [HttpPost("preview")]
        public async Task<IActionResult> PreviewWorkflow(StartWorkflowDto dto)
        {
            var rawResult = await _aiClient.RunWorkflowAsync(dto.Objective, dto.BookingId);
            return Content(rawResult, "application/json");
        }

        // POST: api/agent-workflows/submit-plan
        // Persists the tourist's final (possibly edited) trip plan for admin review.
        [HttpPost("submit-plan")]
        public async Task<IActionResult> SubmitPlan(SubmitTripPlanDto dto)
        {
            if (dto.HotelId.HasValue)
            {
                var hotelExists = await _context.Hotels.AnyAsync(h => h.Id == dto.HotelId.Value);
                if (!hotelExists) return NotFound(new { message = "Selected hotel not found." });
            }
            if (dto.GuideId.HasValue)
            {
                var guideExists = await _context.Guides.AnyAsync(g => g.Id == dto.GuideId.Value);
                if (!guideExists) return NotFound(new { message = "Selected guide not found." });
            }
            if (dto.VehicleId.HasValue)
            {
                var vehicleExists = await _context.Vehicles.AnyAsync(v => v.Id == dto.VehicleId.Value);
                if (!vehicleExists) return NotFound(new { message = "Selected vehicle not found." });
            }

            // 🔥 The AI-customize flow never had a Booking to attach itself to — the tourist
            // picks destinations/hotel/guide/vehicle from scratch, not from an existing
            // Package. Without a Booking, workflow.BookingId stayed null forever, which is
            // exactly why the admin-approve step could never create an Assignment (it only
            // runs `if (workflow.BookingId.HasValue)`). Fix: auto-create a Booking here when
            // the tourist didn't already have one (dto.BookingId is only ever set for the
            // older "customize an existing Package booking" path, if that's used elsewhere).
            // 🔥 Auto-generate a short, human-friendly trip name from the chosen destinations
            // (e.g. "Kandy & Ella 5-Day Trip") instead of showing the tourist's raw free-text
            // objective everywhere — used on booking lists, chat threads, guide/vehicle-owner
            // dashboards, etc.
            var tripDurationDays = dto.Days.Count > 0 ? dto.Days.Count : 1;
            var destinationNames = await _context.Destinations
                .Where(d => dto.DestinationIds.Contains(d.Id))
                .Select(d => d.Name)
                .Distinct()
                .Take(2)
                .ToListAsync();
            var autoTripName = destinationNames.Count switch
            {
                0 => $"{tripDurationDays}-Day Sri Lanka Adventure",
                1 => $"{destinationNames[0]} {tripDurationDays}-Day Trip",
                _ => $"{destinationNames[0]} & {destinationNames[1]} {tripDurationDays}-Day Trip"
            };

            var bookingId = dto.BookingId;
            if (!bookingId.HasValue)
            {
                var autoBooking = new Booking
                {
                    TouristId = CurrentUserId,
                    PackageId = null,
                    CustomTripObjective = dto.Objective,
                    CustomTripName = autoTripName,
                    CustomTripDurationDays = tripDurationDays,
                    Status = BookingStatus.Pending,
                    PlannedStartDate = dto.PlannedStartDate,
                    TotalPrice = dto.EstimatedTotalCost ?? 0,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };
                _context.Bookings.Add(autoBooking);
                await _context.SaveChangesAsync();
                bookingId = autoBooking.Id;
            }
            else
            {
                // Older "customize an existing booking" path — only fill in a name if it
                // doesn't already have one.
                var existingBooking = await _context.Bookings.FindAsync(bookingId.Value);
                if (existingBooking != null && existingBooking.CustomTripName == null && existingBooking.PackageId == null)
                {
                    existingBooking.CustomTripName = autoTripName;
                    await _context.SaveChangesAsync();
                }
            }

            var workflow = new AgentWorkflow
            {
                BookingId = bookingId,
                TouristId = CurrentUserId,
                Objective = dto.Objective,
                PlanJson = JsonSerializer.Serialize(dto),
                Status = WorkflowStatus.Completed,
                ApprovalStatus = ApprovalStatus.PendingApproval,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.AgentWorkflows.Add(workflow);
            await _context.SaveChangesAsync();

            _context.AgentExecutionLogs.Add(new AgentExecutionLog
            {
                WorkflowId = workflow.Id,
                AgentName = "Tourist",
                StepName = "customize_and_submit_plan",
                Output = $"Selected {dto.DestinationIds.Count} destination(s) across {dto.Days.Count} day(s), " +
                         $"hotel #{dto.HotelId}, guide #{dto.GuideId}, vehicle #{dto.VehicleId}. " +
                         (dto.EstimatedTotalCost.HasValue ? $"Estimated total cost: LKR {dto.EstimatedTotalCost.Value:N2}. " : "") +
                         "Submitted for admin approval.",
                Timestamp = DateTime.UtcNow
            });
            await _context.SaveChangesAsync();

            if (bookingId.HasValue)
            {
                var itinerary = new Itinerary
                {
                    BookingId = bookingId.Value,
                    GeneratedBy = "AI+Tourist",
                    ApprovalStatus = ApprovalStatus.PendingApproval,
                    CreatedAt = DateTime.UtcNow,
                    // Each day's ActivitiesJson stores the day's activities PLUS its own
                    // selected destinations/hotel, since a day can now differ from other days.
                    Days = dto.Days.Select(d => new ItineraryDay
                    {
                        DayNumber = d.DayNumber,
                        ActivitiesJson = JsonSerializer.Serialize(new
                        {
                            activities = d.Activities,
                            destinationIds = d.DestinationIds,
                            hotelId = d.HotelId
                        }),
                        Notes = d.Notes
                    }).ToList()
                };
                _context.Itineraries.Add(itinerary);
                await _context.SaveChangesAsync();
            }

            return Ok(new
            {
                workflowId = workflow.Id,
                message = "Your trip plan has been submitted for admin approval."
            });
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

        // GET: api/agent-workflows/pending-approval
        // 🔥 Used to return just the raw workflow (objective + booking id + logs) — the admin
        // had no way to see WHO submitted it or WHAT they picked (destinations/hotel/guide/
        // vehicle) before approving. Now enriched with the tourist's full details and a
        // readable summary of the plan, deserialized from PlanJson.
        [HttpGet("pending-approval")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetPendingApproval()
        {
            var pending = await _context.AgentWorkflows
                .Include(w => w.Logs)
                .Where(w => w.ApprovalStatus == ApprovalStatus.PendingApproval)
                .OrderByDescending(w => w.CreatedAt)
                .ToListAsync();

            var result = new List<object>();
            foreach (var wf in pending)
            {
                User? tourist = wf.TouristId.HasValue ? await _context.Users.FindAsync(wf.TouristId.Value) : null;

                SubmitTripPlanDto? plan = null;
                if (!string.IsNullOrEmpty(wf.PlanJson))
                {
                    try
                    {
                        plan = JsonSerializer.Deserialize<SubmitTripPlanDto>(wf.PlanJson,
                            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                    }
                    catch (JsonException) { /* older AI-only workflow, not in this shape */ }
                }

                string? guideName = null, vehicleName = null, hotelName = null;
                var destinationNames = new List<string>();
                List<object>? dayBreakdown = null;
                if (plan != null)
                {
                    // 🔥 Full plan detail for the admin: not just the aggregate destination/hotel
                    // names, but exactly what each day looks like — so the admin can review the
                    // whole trip plan (start to end) before approving, same as the tourist sees.
                    if (plan.Days.Count > 0)
                    {
                        var dayDestIds = plan.Days.SelectMany(d => d.DestinationIds).Distinct().ToList();
                        var dayHotelIds = plan.Days.Where(d => d.HotelId.HasValue).Select(d => d.HotelId!.Value).Distinct().ToList();
                        var destLookup = await _context.Destinations
                            .Where(d => dayDestIds.Contains(d.Id))
                            .ToDictionaryAsync(d => d.Id, d => d.Name);
                        var hotelLookup = await _context.Hotels
                            .Where(h => dayHotelIds.Contains(h.Id))
                            .ToDictionaryAsync(h => h.Id, h => h.Name);

                        dayBreakdown = plan.Days
                            .OrderBy(d => d.DayNumber)
                            .Select(d => (object)new
                            {
                                d.DayNumber,
                                activities = d.Activities,
                                destinationNames = d.DestinationIds
                                    .Select(id => destLookup.TryGetValue(id, out var n) ? n : $"Destination #{id}")
                                    .ToList(),
                                hotelName = d.HotelId.HasValue
                                    ? (hotelLookup.TryGetValue(d.HotelId.Value, out var hn) ? hn : $"Hotel #{d.HotelId}")
                                    : null
                            })
                            .ToList();
                    }
                    if (plan.GuideId.HasValue)
                    {
                        var g = await _context.Guides.Include(x => x.User).FirstOrDefaultAsync(x => x.Id == plan.GuideId.Value);
                        guideName = g?.User?.Name;
                    }
                    if (plan.VehicleId.HasValue)
                    {
                        var v = await _context.Vehicles.FindAsync(plan.VehicleId.Value);
                        vehicleName = v != null ? (v.Name ?? v.Type) : null;
                    }
                    if (plan.HotelId.HasValue)
                    {
                        var h = await _context.Hotels.FindAsync(plan.HotelId.Value);
                        hotelName = h?.Name;
                    }
                    if (plan.DestinationIds.Count > 0)
                    {
                        destinationNames = await _context.Destinations
                            .Where(d => plan.DestinationIds.Contains(d.Id))
                            .Select(d => d.Name)
                            .ToListAsync();
                    }
                }

                result.Add(new
                {
                    wf.Id,
                    wf.BookingId,
                    wf.Objective,
                    status = wf.Status.ToString(),
                    approvalStatus = wf.ApprovalStatus.ToString(),
                    wf.CreatedAt,
                    logs = wf.Logs,
                    tourist = tourist == null ? null : new
                    {
                        tourist.Id,
                        tourist.Name,
                        tourist.Email,
                        tourist.MobileNumber,
                        tourist.Country
                    },
                    plan = plan == null ? null : new
                    {
                        dayCount = plan.Days.Count,
                        destinationNames,
                        hotelName,
                        guideName,
                        vehicleName,
                        estimatedTotalCost = plan.EstimatedTotalCost,
                        plannedStartDate = plan.PlannedStartDate,
                        days = dayBreakdown
                    }
                });
            }

            return Ok(result);
        }

        // PUT: api/agent-workflows/{id}/approve
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

            // 🔥 Approving a tourist-submitted trip plan didn't used to DO anything with the
            // guide/vehicle the tourist picked while customizing — no Assignment row was ever
            // created, so the guide/vehicle owner never saw the trip on their dashboard. Fix:
            // create the Assignment here (and notify both sides, with their estimated earning).
            // Also keep the Booking's own trip status (shown on Admin/Tourist/Guide/Vehicle
            // Owner sides) in sync with the approval decision.
            if (workflow.BookingId.HasValue)
            {
                var relatedBooking = await _context.Bookings.FindAsync(workflow.BookingId.Value);
                if (relatedBooking != null)
                {
                    if (newStatus == ApprovalStatus.Approved)
                    {
                        relatedBooking.Status = BookingStatus.Confirmed;
                        relatedBooking.UpdatedAt = DateTime.UtcNow;
                        await _context.SaveChangesAsync();
                        await CreateAssignmentFromPlanAsync(workflow);
                    }
                    else if (newStatus == ApprovalStatus.Rejected)
                    {
                        relatedBooking.Status = BookingStatus.Rejected;
                        relatedBooking.UpdatedAt = DateTime.UtcNow;
                        await _context.SaveChangesAsync();
                    }
                }
            }

            if (workflow.TouristId.HasValue &&
                (newStatus == ApprovalStatus.Approved || newStatus == ApprovalStatus.Rejected || newStatus == ApprovalStatus.RevisionRequested))
            {
                var title = newStatus switch
                {
                    ApprovalStatus.Approved => "Trip Plan Approved!",
                    ApprovalStatus.Rejected => "Trip Plan Rejected",
                    _ => "Revision Requested for Your Trip Plan"
                };
                var message = newStatus switch
                {
                    ApprovalStatus.Approved => $"Your AI-planned trip \"{workflow.Objective}\" has been approved by the admin.",
                    ApprovalStatus.Rejected => $"Your AI-planned trip \"{workflow.Objective}\" was rejected. Please try planning again.",
                    _ => $"The admin requested changes to your trip plan \"{workflow.Objective}\". Please review and resubmit."
                };
                await _notificationService.CreateAsync(workflow.TouristId.Value, title, message, NotificationType.AIWorkflow);
            }

            return NoContent();
        }

        // Reads the GuideId/VehicleId the tourist chose while customizing (stored in
        // workflow.PlanJson, since submit-plan serializes the whole SubmitTripPlanDto there)
        // and turns it into a real Assignment row, so the Guide/VehicleOwner dashboards pick
        // it up. Skips silently if PlanJson isn't in that shape (e.g. an old AI-only workflow),
        // if neither a guide nor a vehicle was chosen, or if an Assignment already exists for
        // this booking (so re-approving the same workflow doesn't create duplicates).
        private async Task CreateAssignmentFromPlanAsync(AgentWorkflow workflow)
        {
            SubmitTripPlanDto? plan;
            try
            {
                plan = JsonSerializer.Deserialize<SubmitTripPlanDto>(workflow.PlanJson,
                    new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
            }
            catch (JsonException)
            {
                return;
            }
            if (plan == null || (plan.GuideId == null && plan.VehicleId == null)) return;

            var bookingId = workflow.BookingId!.Value;
            var alreadyAssigned = await _context.Assignments.AnyAsync(a => a.BookingId == bookingId);
            if (alreadyAssigned) return;

            Guide? guide = plan.GuideId.HasValue ? await _context.Guides.FindAsync(plan.GuideId.Value) : null;
            Vehicle? vehicle = plan.VehicleId.HasValue ? await _context.Vehicles.FindAsync(plan.VehicleId.Value) : null;

            // Safety net: the tourist could have picked a guide/vehicle that got assigned to
            // another trip in the time between submitting the plan and the admin approving it.
            // Don't double-book them — just skip that side (admin still sees it wasn't assigned).
            if (guide != null && !guide.IsAvailable) guide = null;
            if (vehicle != null && !vehicle.IsAvailable) vehicle = null;

            var assignment = new Assignment
            {
                BookingId = bookingId,
                GuideId = guide?.Id,
                VehicleId = vehicle?.Id,
                Status = AssignmentStatus.Confirmed, // admin already approved the whole plan
                AssignedAt = DateTime.UtcNow
            };
            _context.Assignments.Add(assignment);

            if (guide != null) guide.IsAvailable = false;
            if (vehicle != null) vehicle.IsAvailable = false;

            await _context.SaveChangesAsync();

            var booking = await _context.Bookings.Include(b => b.Package).FirstOrDefaultAsync(b => b.Id == bookingId);
            var days = booking?.Package?.DurationDays ?? booking?.CustomTripDurationDays ?? 1;
            var packageName = booking?.Package?.Name ?? booking?.CustomTripName ?? booking?.CustomTripObjective ?? "a trip";

            if (guide != null)
            {
                const decimal guideFeePerDay = 2500m;
                var earning = guideFeePerDay * days;
                await _notificationService.CreateAsync(guide.UserId, "New Trip Assigned!",
                    $"You've been assigned to \"{packageName}\" ({days} day(s)). " +
                    $"Estimated earning: LKR {earning:N2}. Check My Dashboard for the full trip summary.",
                    NotificationType.General);
            }
            if (vehicle != null)
            {
                var earning = vehicle.PricePerKm * (decimal)VehiclePricing.AssumedKmPerDay * days;
                await _notificationService.CreateAsync(vehicle.OperatorId, "New Trip Assigned!",
                    $"Your vehicle has been assigned to \"{packageName}\" ({days} day(s)). " +
                    $"Estimated earning: LKR {earning:N2}. Check My Dashboard for the full trip summary.",
                    NotificationType.General);
            }
        }
    }
}