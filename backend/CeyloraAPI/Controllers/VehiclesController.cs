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
    public class VehiclesController : ControllerBase 
    { 
        private readonly AppDbContext _context; 
  
        public VehiclesController(AppDbContext context) 
        { 
            _context = context; 
        } 
  
        // GET: api/vehicles?region=Kandy&type=Van&available=true&page=1&pageSize=10 
        [HttpGet] 
        public async Task<ActionResult<PagedResultDto<Vehicle>>> GetAll( 
            [FromQuery] string? region, 
            [FromQuery] string? type, 
            [FromQuery] bool? available, 
            [FromQuery] int page = 1, 
            [FromQuery] int pageSize = 10) 
        { 
            var query = _context.Vehicles.Include(v => v.Images).AsQueryable(); 
  
            if (!string.IsNullOrWhiteSpace(region)) 
                query = query.Where(v => v.Region.ToLower() == region.ToLower()); 
  
            if (!string.IsNullOrWhiteSpace(type)) 
                query = query.Where(v => v.Type.ToLower() == type.ToLower()); 
  
            if (available.HasValue) 
                query = query.Where(v => v.IsAvailable == available.Value); 
  
            var totalCount = await query.CountAsync(); 
            var items = await query 
                .Skip((page - 1) * pageSize) 
                .Take(pageSize) 
                .ToListAsync(); 
  
            return Ok(new PagedResultDto<Vehicle> 
            { 
                Items = items, 
                TotalCount = totalCount, 
                Page = page, 
                PageSize = pageSize 
            }); 
        } 
  
        // GET: api/vehicles/5 
        [HttpGet("{id}")] 
        public async Task<ActionResult<Vehicle>> GetById(int id) 
        { 
            var vehicle = await _context.Vehicles.Include(v => v.Images).FirstOrDefaultAsync(v => 
v.Id == id); 
            if (vehicle == null) return NotFound(new { message = "Vehicle not found." }); 
            return Ok(vehicle); 
        } 
  
        // POST: api/vehicles (Admin only) 
        [HttpPost] 
        [Authorize(Roles = "Admin")] 
        public async Task<ActionResult<Vehicle>> Create(VehicleDto dto) 
        { 
            var operatorExists = await _context.Users.AnyAsync(u => u.Id == dto.OperatorId); 
            if (!operatorExists) return NotFound(new { message = "Operator user not found." }); 
  
            var vehicle = new Vehicle 
            { 
                OperatorId = dto.OperatorId, 
                Type = dto.Type, 
                Capacity = dto.Capacity, 
                Region = dto.Region, 
                IsAvailable = dto.IsAvailable 
            }; 
  
            _context.Vehicles.Add(vehicle); 
            await _context.SaveChangesAsync(); 
  
            return CreatedAtAction(nameof(GetById), new { id = vehicle.Id }, vehicle); 
        } 
  
        // PUT: api/vehicles/5 (Admin only) 
        [HttpPut("{id}")] 
        [Authorize(Roles = "Admin")] 
        public async Task<IActionResult> Update(int id, VehicleDto dto) 
        { 
            var vehicle = await _context.Vehicles.FindAsync(id); 
            if (vehicle == null) return NotFound(new { message = "Vehicle not found." }); 
  
            vehicle.Type = dto.Type; 
            vehicle.Capacity = dto.Capacity; 
            vehicle.Region = dto.Region; 
            vehicle.IsAvailable = dto.IsAvailable; 
  
            await _context.SaveChangesAsync(); 
            return NoContent(); 
        } 
  
        // DELETE: api/vehicles/5 (Admin only) 
        [HttpDelete("{id}")] 
        [Authorize(Roles = "Admin")] 
        public async Task<IActionResult> Delete(int id) 
        { 
            var vehicle = await _context.Vehicles.FindAsync(id); 
            if (vehicle == null) return NotFound(new { message = "Vehicle not found." }); 
  
            _context.Vehicles.Remove(vehicle); 
            await _context.SaveChangesAsync(); 
            return NoContent(); 
        } 
  
        // POST: api/vehicles/5/images (Admin only) — add image URL to gallery 
        [HttpPost("{id}/images")] 
        [Authorize(Roles = "Admin")] 
        public async Task<ActionResult<VehicleImage>> AddImage(int id, [FromBody] string imageUrl) 
        { 
            var vehicle = await _context.Vehicles.FindAsync(id); 
            if (vehicle == null) return NotFound(new { message = "Vehicle not found." }); 
  
            var image = new VehicleImage 
            { 
                VehicleId = id, 
                ImageUrl = imageUrl, 
                IsCover = !await _context.VehicleImages.AnyAsync(vi => vi.VehicleId == id), 
                UploadedAt = DateTime.UtcNow 
            }; 
  
            _context.VehicleImages.Add(image); 
            await _context.SaveChangesAsync(); 
  
            return Ok(image); 
        } 
    } 
} 