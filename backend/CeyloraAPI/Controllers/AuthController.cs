using CeyloraAPI.Data;
using CeyloraAPI.DTOs;
using CeyloraAPI.Models;
using CeyloraAPI.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CeyloraAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IJwtService _jwtService;
        private readonly IEmailService _emailService;
        private readonly INotificationService _notificationService;
        private readonly IWebHostEnvironment _env;

        public AuthController(AppDbContext context, IJwtService jwtService, IEmailService emailService,
            INotificationService notificationService, IWebHostEnvironment env)
        {
            _context = context;
            _jwtService = jwtService;
            _emailService = emailService;
            _notificationService = notificationService;
            _env = env;
        }

        // A Tourist/Admin is always "verified". A Guide/VehicleOwner is verified only once
        // an Admin has approved their documents (see GuidesController/VehicleOwnersController).
        private async Task<bool> ComputeIsVerifiedAsync(User user)
        {
            if (user.Role == UserRole.Guide)
            {
                var guide = await _context.Guides.FirstOrDefaultAsync(g => g.UserId == user.Id);
                return guide?.IsVerified ?? true; // no Guide row yet = nothing to gate on
            }
            if (user.Role == UserRole.VehicleOwner)
            {
                var vo = await _context.VehicleOwners.FirstOrDefaultAsync(v => v.UserId == user.Id);
                return vo?.IsVerified ?? true;
            }
            return true;
        }

        private async Task<string> SaveDocumentAsync(IFormFile file, string subfolder, string prefix)
        {
            var uploadsFolder = Path.Combine(_env.WebRootPath ?? "wwwroot", "uploads", subfolder);
            Directory.CreateDirectory(uploadsFolder);

            var fileName = $"{prefix}-{Guid.NewGuid()}{Path.GetExtension(file.FileName)}";
            var filePath = Path.Combine(uploadsFolder, fileName);

            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            return $"/uploads/{subfolder}/{fileName}";
        }

        [HttpPost("register")]
        public async Task<ActionResult<AuthResponseDto>> Register(RegisterDto dto)
        {
            if (await _context.Users.AnyAsync(u => u.Email == dto.Email))
                return BadRequest(new { message = "Email already registered." });

            // Guide/VehicleOwner accounts must go through their dedicated registration
            // (register-guide / register-vehicle-owner) so their verification documents are collected.
            if (dto.Role == UserRole.Guide || dto.Role == UserRole.VehicleOwner)
                return BadRequest(new { message = "Please use the Guide or Vehicle Owner registration form." });

            var user = new User
            {
                Name = dto.Name,
                Email = dto.Email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password),
                Role = dto.Role,
                Country = dto.Country,
                MobileNumber = dto.MobileNumber,
                CreatedAt = DateTime.UtcNow
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            _ = _emailService.SendWelcomeEmailAsync(user.Email, user.Name);
            await _notificationService.CreateAsync(
                user.Id, "Welcome to CEYLORA!", $"Hi {user.Name}, thanks for joining CEYLORA. Start exploring destinations and plan your first trip!", NotificationType.Welcome);

            var token = _jwtService.GenerateToken(user);

            return Ok(new AuthResponseDto
            {
                UserId = user.Id,
                Name = user.Name,
                Email = user.Email,
                Role = user.Role.ToString(),
                Token = token,
                IsVerified = true
            });
        }

        // POST: api/auth/register-guide (multipart/form-data)
        // Creates the User + Guide profile together, with IsVerified=false until an Admin
        // reviews the uploaded Tourism ID photo.
        [HttpPost("register-guide")]
        public async Task<ActionResult<AuthResponseDto>> RegisterGuide(
            [FromForm] string name, [FromForm] string email, [FromForm] string password,
            [FromForm] int age, [FromForm] string region, [FromForm] string nicNumber,
            [FromForm] string mobileNumber, [FromForm] string? country,
            [FromForm] string? languages, IFormFile tourismIdPhoto)
        {
            if (await _context.Users.AnyAsync(u => u.Email == email))
                return BadRequest(new { message = "Email already registered." });
            if (tourismIdPhoto == null || tourismIdPhoto.Length == 0)
                return BadRequest(new { message = "Please upload a photo of your Tourism ID." });

            var user = new User
            {
                Name = name,
                Email = email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
                Role = UserRole.Guide,
                Age = age,
                Country = country,
                MobileNumber = mobileNumber,
                CreatedAt = DateTime.UtcNow
            };
            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            var photoUrl = await SaveDocumentAsync(tourismIdPhoto, "guide-documents", $"tourism-id-{user.Id}");

            var guide = new Guide
            {
                UserId = user.Id,
                Region = region,
                Languages = languages,
                NicNumber = nicNumber,
                TourismIdPhotoUrl = photoUrl,
                IsAvailable = true,
                IsVerified = false // pending Admin review
            };
            _context.Guides.Add(guide);
            await _context.SaveChangesAsync();

            _ = _emailService.SendWelcomeEmailAsync(user.Email, user.Name);
            await _notificationService.CreateAsync(user.Id, "Welcome to CEYLORA!",
                $"Hi {user.Name}, your guide application was submitted. We'll notify you once it's reviewed.", NotificationType.Welcome);

            var token = _jwtService.GenerateToken(user);
            return Ok(new AuthResponseDto
            {
                UserId = user.Id,
                Name = user.Name,
                Email = user.Email,
                Role = user.Role.ToString(),
                Token = token,
                IsVerified = false
            });
        }

        // POST: api/auth/register-vehicle-owner (multipart/form-data)
        // Creates the User + VehicleOwner profile + their first Vehicle together, all pending
        // Admin review (documents + vehicle photos).
        [HttpPost("register-vehicle-owner")]
        public async Task<ActionResult<AuthResponseDto>> RegisterVehicleOwner(
            [FromForm] string name, [FromForm] string email, [FromForm] string password,
            [FromForm] int age, [FromForm] string region, [FromForm] string nicNumber,
            [FromForm] string mobileNumber, [FromForm] string? country, IFormFile drivingLicensePhoto,
            [FromForm] string vehicleType, [FromForm] string vehicleName,
            [FromForm] int manufacturerYear, [FromForm] int numberOfSeats,
            List<IFormFile> vehiclePhotos)
        {
            if (await _context.Users.AnyAsync(u => u.Email == email))
                return BadRequest(new { message = "Email already registered." });
            if (drivingLicensePhoto == null || drivingLicensePhoto.Length == 0)
                return BadRequest(new { message = "Please upload a photo of your driving license." });
            if (vehiclePhotos == null || vehiclePhotos.Count == 0)
                return BadRequest(new { message = "Please upload at least one photo of your vehicle." });

            var user = new User
            {
                Name = name,
                Email = email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
                Role = UserRole.VehicleOwner,
                Age = age,
                Country = country,
                MobileNumber = mobileNumber,
                CreatedAt = DateTime.UtcNow
            };
            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            var licenseUrl = await SaveDocumentAsync(drivingLicensePhoto, "vehicle-owner-documents", $"license-{user.Id}");

            var vehicleOwner = new VehicleOwner
            {
                UserId = user.Id,
                Region = region,
                NicNumber = nicNumber,
                DrivingLicensePhotoUrl = licenseUrl,
                IsVerified = false // pending Admin review
            };
            _context.VehicleOwners.Add(vehicleOwner);

            var vehicle = new Vehicle
            {
                OperatorId = user.Id,
                Type = vehicleType,
                Name = vehicleName,
                ManufacturerYear = manufacturerYear,
                Capacity = numberOfSeats,
                Region = region,
                PricePerKm = VehiclePricing.GetPricePerKm(vehicleType), // fixed rate by vehicle type
                IsAvailable = true
            };
            _context.Vehicles.Add(vehicle);
            await _context.SaveChangesAsync();

            var isCover = true;
            foreach (var photo in vehiclePhotos)
            {
                var url = await SaveDocumentAsync(photo, "vehicle-photos", $"vehicle-{vehicle.Id}");
                _context.VehicleImages.Add(new VehicleImage
                {
                    VehicleId = vehicle.Id,
                    ImageUrl = url,
                    IsCover = isCover,
                    UploadedAt = DateTime.UtcNow
                });
                isCover = false;
            }
            await _context.SaveChangesAsync();

            _ = _emailService.SendWelcomeEmailAsync(user.Email, user.Name);
            await _notificationService.CreateAsync(user.Id, "Welcome to CEYLORA!",
                $"Hi {user.Name}, your vehicle owner application was submitted. We'll notify you once it's reviewed.", NotificationType.Welcome);

            var token = _jwtService.GenerateToken(user);
            return Ok(new AuthResponseDto
            {
                UserId = user.Id,
                Name = user.Name,
                Email = user.Email,
                Role = user.Role.ToString(),
                Token = token,
                IsVerified = false
            });
        }

        [HttpPost("login")]
        public async Task<ActionResult<AuthResponseDto>> Login(LoginDto dto)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == dto.Email);

            if (user == null || !BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash))
                return Unauthorized(new { message = "Invalid email or password." });

            var token = _jwtService.GenerateToken(user);
            var isVerified = await ComputeIsVerifiedAsync(user);

            return Ok(new AuthResponseDto
            {
                UserId = user.Id,
                Name = user.Name,
                Email = user.Email,
                Role = user.Role.ToString(),
                Token = token,
                IsVerified = isVerified
            });
        }
    }
}
