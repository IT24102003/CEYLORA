using CeyloraAPI.Data;
using CeyloraAPI.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace CeyloraAPI.Controllers
{
    [ApiController]
    [Route("api/users")]
    [Authorize]
    public class UsersController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IWebHostEnvironment _env;

        public UsersController(AppDbContext context, IWebHostEnvironment env)
        {
            _context = context;
            _env = env;
        }

        private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        // GET: api/users?role=Guide&search=john (Admin only)
        // Used by the admin panel both to link a User account with role=Guide to a Guide
        // profile, and (🔥 now also) to power the standalone "Users" tab's search/filter.
        [HttpGet]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetUsers([FromQuery] string? role, [FromQuery] string? search)
        {
            var query = _context.Users.AsQueryable();
            if (!string.IsNullOrWhiteSpace(role) && Enum.TryParse<Models.UserRole>(role, true, out var roleEnum))
                query = query.Where(u => u.Role == roleEnum);

            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.ToLower();
                query = query.Where(u => u.Name.ToLower().Contains(s) || u.Email.ToLower().Contains(s));
            }

            // Previously: 3 sequential round trips (Users, then all Guide user-ids, then
            // all VehicleOwner user-ids), joined in memory. Each is a chance to hit a
            // slow beat on Supabase's free-tier pooler, and they add up one after another.
            // EXISTS subqueries let EF Core fold this into a single SQL statement.
            var result = await query
                .OrderBy(u => u.Name)
                .Select(u => new
                {
                    id = u.Id,
                    name = u.Name,
                    email = u.Email,
                    role = u.Role.ToString(),
                    age = u.Age,
                    country = u.Country,
                    mobileNumber = u.MobileNumber,
                    profilePictureUrl = u.ProfilePictureUrl,
                    createdAt = u.CreatedAt,
                    hasGuideProfile = _context.Guides.Any(g => g.UserId == u.Id),
                    hasVehicleOwnerProfile = _context.VehicleOwners.Any(v => v.UserId == u.Id)
                })
                .ToListAsync();

            return Ok(result);
        }

        // DELETE: api/users/5 (Admin only)
        // 🔥 Lets the admin remove a stray/test/abandoned account from the new Users tab.
        // Blocks deleting the LAST remaining Admin account so the admin panel can never be
        // locked out, and blocks deleting an account that still owns bookings (that history
        // must stay attached to a real user) — delete/reassign those first.
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> DeleteUser(int id)
        {
            var user = await _context.Users.FindAsync(id);
            if (user == null) return NotFound();

            if (user.Role == Models.UserRole.Admin)
            {
                var adminCount = await _context.Users.CountAsync(u => u.Role == Models.UserRole.Admin);
                if (adminCount <= 1)
                    return BadRequest(new { message = "Can't delete the last remaining Admin account." });
            }

            var hasBookings = await _context.Bookings.AnyAsync(b => b.TouristId == id);
            if (hasBookings)
                return BadRequest(new { message = "This user has bookings on record and can't be deleted." });

            _context.Users.Remove(user);
            await _context.SaveChangesAsync();
            return NoContent();
        }

        // GET: api/users/me
        [HttpGet("me")]
        public async Task<ActionResult<UserProfileDto>> GetMyProfile()
        {
            var user = await _context.Users.FindAsync(CurrentUserId);
            if (user == null) return NotFound();

            bool isVerified = true;
            if (user.Role == Models.UserRole.Guide)
            {
                var guide = await _context.Guides.FirstOrDefaultAsync(g => g.UserId == user.Id);
                isVerified = guide?.IsVerified ?? true;
            }
            else if (user.Role == Models.UserRole.VehicleOwner)
            {
                var vo = await _context.VehicleOwners.FirstOrDefaultAsync(v => v.UserId == user.Id);
                isVerified = vo?.IsVerified ?? true;
            }

            return Ok(new UserProfileDto
            {
                Id = user.Id,
                Name = user.Name,
                Email = user.Email,
                Role = user.Role.ToString(),
                Age = user.Age,
                Country = user.Country,
                MobileNumber = user.MobileNumber,
                ProfilePictureUrl = user.ProfilePictureUrl,
                IsVerified = isVerified
            });
        }

        // PUT: api/users/me
        [HttpPut("me")]
        public async Task<IActionResult> UpdateMyProfile(UpdateProfileDto dto)
        {
            var user = await _context.Users.FindAsync(CurrentUserId);
            if (user == null) return NotFound();

            user.Name = dto.Name;
            user.Age = dto.Age;
            user.Country = dto.Country;
            user.MobileNumber = dto.MobileNumber;

            await _context.SaveChangesAsync();
            return NoContent();
        }

        // POST: api/users/me/profile-picture
        [HttpPost("me/profile-picture")]
        public async Task<IActionResult> UploadProfilePicture(IFormFile file)
        {
            if (file == null || file.Length == 0)
                return BadRequest(new { message = "No file uploaded." });

            var user = await _context.Users.FindAsync(CurrentUserId);
            if (user == null) return NotFound();

            var uploadsFolder = Path.Combine(_env.WebRootPath ?? "wwwroot", "uploads", "profile-pictures");
            Directory.CreateDirectory(uploadsFolder);

            var fileName = $"user-{CurrentUserId}-{Guid.NewGuid()}{Path.GetExtension(file.FileName)}";
            var filePath = Path.Combine(uploadsFolder, fileName);

            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            var relativeUrl = $"/uploads/profile-pictures/{fileName}";
            user.ProfilePictureUrl = relativeUrl;
            await _context.SaveChangesAsync();

            return Ok(new { profilePictureUrl = relativeUrl });
        }
    }
}