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
    public class PackagesController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IPricingService _pricingService;

        public PackagesController(AppDbContext context, IPricingService pricingService)
        {
            _context = context;
            _pricingService = pricingService;
        }

        // GET: api/packages?published=true&page=1&pageSize=10
        [HttpGet]
        public async Task<ActionResult<PagedResultDto<Package>>> GetAll(
            [FromQuery] bool? published,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            var query = _context.Packages.AsQueryable();

            if (published.HasValue)
                query = query.Where(p => p.IsPublished == published.Value);

            var totalCount = await query.CountAsync();
            var items = await query
                .OrderByDescending(p => p.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            return Ok(new PagedResultDto<Package>
            {
                Items = items,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        // GET: api/packages/5
        [HttpGet("{id}")]
        public async Task<ActionResult<Package>> GetById(int id)
        {
            var package = await _context.Packages
                .Include(p => p.PackageDestinations)
                .ThenInclude(pd => pd.Destination)
                .FirstOrDefaultAsync(p => p.Id == id);

            if (package == null) return NotFound(new { message = "Package not found." });
            return Ok(package);
        }

        // POST: api/packages (Admin only)
        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<Package>> Create(PackageDto dto)
        {
            var package = new Package
            {
                Name = dto.Name,
                Description = dto.Description,
                BasePrice = dto.BasePrice,
                DurationDays = dto.DurationDays,
                IsPublished = dto.IsPublished,
                CreatedAt = DateTime.UtcNow
            };

            _context.Packages.Add(package);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetById), new { id = package.Id }, package);
        }

        // PUT: api/packages/5 (Admin only)
        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(int id, PackageDto dto)
        {
            var package = await _context.Packages.FindAsync(id);
            if (package == null) return NotFound(new { message = "Package not found." });

            package.Name = dto.Name;
            package.Description = dto.Description;
            package.BasePrice = dto.BasePrice;
            package.DurationDays = dto.DurationDays;
            package.IsPublished = dto.IsPublished;

            await _context.SaveChangesAsync();
            return NoContent();
        }

        // DELETE: api/packages/5 (Admin only)
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var package = await _context.Packages.FindAsync(id);
            if (package == null) return NotFound(new { message = "Package not found." });

            _context.Packages.Remove(package);
            await _context.SaveChangesAsync();
            return NoContent();
        }

        // 🔥 BUSINESS-SPECIFIC OPERATION: Dynamic Price Quote
        // POST: api/packages/5/quote
        [HttpPost("{id}/quote")]
        public async Task<ActionResult<PriceQuoteResponseDto>> GetPriceQuote(int id, PriceQuoteRequestDto request)
        {
            var package = await _context.Packages.FindAsync(id);
            if (package == null) return NotFound(new { message = "Package not found." });

            if (request.GroupSize < 1)
                return BadRequest(new { message = "Group size must be at least 1." });

            var quote = _pricingService.CalculatePrice(package, request.GroupSize, request.TravelDate);
            return Ok(quote);
        }
    }
}