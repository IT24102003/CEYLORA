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

        // GET: api/users/me
        [HttpGet("me")]
        public async Task<ActionResult<UserProfileDto>> GetMyProfile()
        {
            var user = await _context.Users.FindAsync(CurrentUserId);
            if (user == null) return NotFound();

            return Ok(new UserProfileDto
            {
                Id = user.Id,
                Name = user.Name,
                Email = user.Email,
                Role = user.Role.ToString(),
                Age = user.Age,
                Country = user.Country,
                MobileNumber = user.MobileNumber,
                ProfilePictureUrl = user.ProfilePictureUrl
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