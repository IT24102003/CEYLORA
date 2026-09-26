using CeyloraAPI.Data; 
using CeyloraAPI.DTOs; 
using CeyloraAPI.Models; 
using CeyloraAPI.Services; 
using Microsoft.AspNetCore.Authorization; 
using Microsoft.AspNetCore.Mvc; 
using Microsoft.EntityFrameworkCore; 
  
namespace CeyloraAPI.Controllers 
{ 
    [ApiController] 
    [Route("api/[controller]")] 
    [Authorize] 
    public class AssignmentsController : ControllerBase 
    { 
        private readonly AppDbContext _context; 
        private readonly IAssignmentService _assignmentService; 
  
        public AssignmentsController(AppDbContext context, IAssignmentService assignmentService) 
        { 
            _context = context; 
            _assignmentService = assignmentService; 
        } 
  
        // GET: api/assignments/booking/5 
        [HttpGet("booking/{bookingId}")] 
        public async Task<ActionResult<Assignment>> GetByBooking(int bookingId) 
        { 
            var assignment = await _context.Assignments 
                .Include(a => a.Guide) 
                .Include(a => a.Vehicle) 
                .FirstOrDefaultAsync(a => a.BookingId == bookingId); 
  
            if (assignment == null) return NotFound(new { message = "No assignment found for this booking." }); 
            return Ok(assignment); 
        } 
  
        // 🔥 BUSINESS-SPECIFIC OPERATION: Auto-Matching 
        // POST: api/assignments/auto-match 
        [HttpPost("auto-match")] 
        [Authorize(Roles = "Admin")] 
        public async Task<ActionResult<AssignmentResultDto>> AutoMatch(AutoMatchRequestDto request) 
        { 
            var result = await _assignmentService.AutoMatchAsync( 
                request.BookingId, request.Region, request.PreferredLanguage); 
  
            if (!result.Success) return BadRequest(result); 
            return Ok(result); 
        } 
  
        // PUT: api/assignments/5/status (Admin only) 
        [HttpPut("{id}/status")] 
        [Authorize(Roles = "Admin")] 
        public async Task<IActionResult> UpdateStatus(int id, UpdateAssignmentStatusDto dto) 
        { 
            var assignment = await _context.Assignments.FindAsync(id); 
            if (assignment == null) return NotFound(new { message = "Assignment not found." }); 
  
            if (!Enum.TryParse<AssignmentStatus>(dto.Status, true, out var newStatus)) 
                return BadRequest(new { message = "Invalid status value." }); 
  
            // Releasing a cancelled assignment frees the guide/vehicle again 
            if (newStatus == AssignmentStatus.Cancelled) 
            { 
                if (assignment.GuideId.HasValue) 
                { 
                    var guide = await _context.Guides.FindAsync(assignment.GuideId.Value); 
                    if (guide != null) guide.IsAvailable = true; 
                } 
                if (assignment.VehicleId.HasValue) 
                { 
                    var vehicle = await _context.Vehicles.FindAsync(assignment.VehicleId.Value); 
                    if (vehicle != null) vehicle.IsAvailable = true; 
                } 
            } 
  
            assignment.Status = newStatus; 
            await _context.SaveChangesAsync(); 
            return NoContent(); 
        } 
    } 
} 
