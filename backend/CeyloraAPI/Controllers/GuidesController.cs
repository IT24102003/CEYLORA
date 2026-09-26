using CeyloraAPI.Data; 
using CeyloraAPI.DTOs; 
using CeyloraAPI.Models; 
using Microsoft.AspNetCore.Authorization; 
using Microsoft.AspNetCore.Mvc; 
using Microsoft.EntityFrameworkCore; 
  
namespace CeyloraAPI.Controllers 
{ 
    [ApiController] 
    [Route("api/[controller]")] 
    public class GuidesController : ControllerBase 
    { 
        private readonly AppDbContext _context; 
  
        public GuidesController(AppDbContext context) 
        { 
            _context = context; 
        }

      // GET: api/guides?region=Kandy&available=true&page=1&pageSize=10 
        [HttpGet] 
        public async Task<ActionResult<PagedResultDto<Guide>>> GetAll( 
            [FromQuery] string? region, 
            [FromQuery] bool? available, 
            [FromQuery] int page = 1, 
            [FromQuery] int pageSize = 10) 
        { 
            var query = _context.Guides.AsQueryable(); 
  
            if (!string.IsNullOrWhiteSpace(region)) 
                query = query.Where(g => g.Region.ToLower() == region.ToLower()); 
  
            if (available.HasValue) 
                query = query.Where(g => g.IsAvailable == available.Value); 
  
            var totalCount = await query.CountAsync(); 
            var items = await query 
                .OrderByDescending(g => g.Rating) 
                .Skip((page - 1) * pageSize) 
                .Take(pageSize) 
                .ToListAsync(); 
  
            return Ok(new PagedResultDto<Guide> 
            { 
                Items = items, 
                TotalCount = totalCount, 
                Page = page, 
                PageSize = pageSize 
            }); 
        } 

      // GET: api/guides/5 
        [HttpGet("{id}")] 
        public async Task<ActionResult<Guide>> GetById(int id) 
        { 
            var guide = await _context.Guides.FindAsync(id); 
            if (guide == null) return NotFound(new { message = "Guide not found." }); 
            return Ok(guide); 
        } 
  
        // POST: api/guides (Admin only) 
        [HttpPost] 
        [Authorize(Roles = "Admin")] 
        public async Task<ActionResult<Guide>> Create(GuideDto dto) 
        { 
            var userExists = await _context.Users.AnyAsync(u => u.Id == dto.UserId); 
            if (!userExists) return NotFound(new { message = "User not found." }); 
  
            var guide = new Guide 
            { 
                UserId = dto.UserId, 
                Languages = dto.Languages, 
                Region = dto.Region, 
                Rating = 0, 
                IsAvailable = dto.IsAvailable 
            }; 
  
            _context.Guides.Add(guide); 
            await _context.SaveChangesAsync(); 
  
            return CreatedAtAction(nameof(GetById), new { id = guide.Id }, guide); 
        } 
  
        // PUT: api/guides/5   
          [HttpPut("{id}")] 
        [Authorize] 
        public async Task<IActionResult> Update(int id, GuideDto dto) 
        { 
            var guide = await _context.Guides.FindAsync(id); 
            if (guide == null) return NotFound(new { message = "Guide not found." }); 
  
            guide.Languages = dto.Languages; 
            guide.Region = dto.Region; 
            guide.IsAvailable = dto.IsAvailable; 
  
            await _context.SaveChangesAsync(); 
            return NoContent(); 
        } 
  
        // PUT: api/guides/5/availability 
        [HttpPut("{id}/availability")] 
        [Authorize(Roles = "Guide,Admin")] 
        public async Task<IActionResult> ToggleAvailability(int id, [FromBody] bool isAvailable) 
        { 
            var guide = await _context.Guides.FindAsync(id); 
            if (guide == null) return NotFound(new { message = "Guide not found." }); 
  
            guide.IsAvailable = isAvailable; 
            await _context.SaveChangesAsync(); 
            return NoContent(); 
        } 
  
        // DELETE: api/guides/5 (Admin only) 
        [HttpDelete("{id}")] 
        [Authorize(Roles = "Admin")] 
        public async Task<IActionResult> Delete(int id) 
        { 
            var guide = await _context.Guides.FindAsync(id); 
            if (guide == null) return NotFound(new { message = "Guide not found." });

             _context.Guides.Remove(guide); 
            await _context.SaveChangesAsync(); 
            return NoContent(); 
        } 
    } 
} 
 
