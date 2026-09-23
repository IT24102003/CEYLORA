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
    public class PackagesController : ControllerBase
    {
        private readonly AppDbContext _context;

        public PackagesController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<PackageDto>>> GetPackages([FromQuery] bool onlyPublished = true)
        {
            var query = _context.Packages
                .Include(p => p.PackageDestinations)
                .ThenInclude(pd => pd.Destination)
                .AsQueryable();

            if (onlyPublished)
                query = query.Where(p => p.IsPublished);

            var packages = await query.Select(p => new PackageDto
            {
                Id = p.Id,
                Name = p.Name,
                Description = p.Description,
                BasePrice = p.BasePrice,
                DurationDays = p.DurationDays,
                IsPublished = p.IsPublished,
                Destinations = p.PackageDestinations.Select(pd => new DestinationDto
                {
                    Id = pd.Destination.Id,
                    Name = pd.Destination.Name,
                    Region = pd.Destination.Region,
                    Category = pd.Destination.Category,
                    ImageUrl = pd.Destination.ImageUrl
                }).ToList()
            }).ToListAsync();

            return Ok(packages);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<PackageDto>> GetPackage(int id)
        {
            var p = await _context.Packages
                .Include(p => p.PackageDestinations)
                .ThenInclude(pd => pd.Destination)
                .FirstOrDefaultAsync(p => p.Id == id);

            if (p == null) return NotFound(new { message = "Package not found." });

            return Ok(new PackageDto
            {
                Id = p.Id,
                Name = p.Name,
                Description = p.Description,
                BasePrice = p.BasePrice,
                DurationDays = p.DurationDays,
                IsPublished = p.IsPublished,
                Destinations = p.PackageDestinations.Select(pd => new DestinationDto
                {
                    Id = pd.Destination.Id,
                    Name = pd.Destination.Name,
                    Region = pd.Destination.Region,
                    Category = pd.Destination.Category,
                    ImageUrl = pd.Destination.ImageUrl
                }).ToList()
            });
        }

        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<PackageDto>> CreatePackage(CreatePackageDto dto)
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

            if (dto.DestinationIds.Any())
            {
                int dayNumber = 1;
                foreach (var destId in dto.DestinationIds)
                {
                    _context.PackageDestinations.Add(new PackageDestination
                    {
                        PackageId = package.Id,
                        DestinationId = destId,
                        DayNumber = dayNumber++
                    });
                }
                await _context.SaveChangesAsync();
            }

            return CreatedAtAction(nameof(GetPackage), new { id = package.Id }, new PackageDto
            {
                Id = package.Id,
                Name = package.Name,
                Description = package.Description,
                BasePrice = package.BasePrice,
                DurationDays = package.DurationDays,
                IsPublished = package.IsPublished
            });
        }
    }
}
