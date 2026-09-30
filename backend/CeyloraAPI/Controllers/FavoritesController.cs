using CeyloraAPI.Data;
using CeyloraAPI.DTOs;
using CeyloraAPI.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace CeyloraAPI.Controllers
{
    [ApiController]
    [Route("api/favorites")]
    [Authorize]
    public class FavoritesController : ControllerBase
    {
        private readonly AppDbContext _context;

        public FavoritesController(AppDbContext context)
        {
            _context = context;
        }

        private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        // GET: api/favorites?itemType=Hotel   (itemType optional — omit to get everything)
        [HttpGet]
        public async Task<ActionResult<List<Favorite>>> GetMyFavorites([FromQuery] string? itemType)
        {
            var query = _context.Favorites.Where(f => f.UserId == CurrentUserId);

            if (!string.IsNullOrWhiteSpace(itemType))
                query = query.Where(f => f.ItemType == itemType);

            var favorites = await query.OrderByDescending(f => f.CreatedAt).ToListAsync();
            return Ok(favorites);
        }

        // GET: api/favorites/check?itemType=Hotel&itemId=3
        [HttpGet("check")]
        public async Task<ActionResult<bool>> IsFavorite([FromQuery] string itemType, [FromQuery] int itemId)
        {
            var exists = await _context.Favorites.AnyAsync(
                f => f.UserId == CurrentUserId && f.ItemType == itemType && f.ItemId == itemId);
            return Ok(exists);
        }

        // POST: api/favorites
        [HttpPost]
        public async Task<ActionResult<Favorite>> Add(CreateFavoriteDto dto)
        {
            var validTypes = new[]
            {
                FavoriteItemType.Destination, FavoriteItemType.Package,
                FavoriteItemType.Hotel, FavoriteItemType.Guide, FavoriteItemType.Vehicle
            };
            if (!validTypes.Contains(dto.ItemType))
                return BadRequest(new { message = "Invalid itemType." });

            var alreadyExists = await _context.Favorites.AnyAsync(
                f => f.UserId == CurrentUserId && f.ItemType == dto.ItemType && f.ItemId == dto.ItemId);
            if (alreadyExists)
                return Ok(new { message = "Already in favorites." });

            var favorite = new Favorite
            {
                UserId = CurrentUserId,
                ItemType = dto.ItemType,
                ItemId = dto.ItemId,
                CreatedAt = DateTime.UtcNow
            };

            _context.Favorites.Add(favorite);
            await _context.SaveChangesAsync();

            return Ok(favorite);
        }

        // DELETE: api/favorites?itemType=Hotel&itemId=3
        [HttpDelete]
        public async Task<IActionResult> Remove([FromQuery] string itemType, [FromQuery] int itemId)
        {
            var favorite = await _context.Favorites.FirstOrDefaultAsync(
                f => f.UserId == CurrentUserId && f.ItemType == itemType && f.ItemId == itemId);

            if (favorite == null) return NotFound(new { message = "Not in favorites." });

            _context.Favorites.Remove(favorite);
            await _context.SaveChangesAsync();
            return NoContent();
        }
    }
}
