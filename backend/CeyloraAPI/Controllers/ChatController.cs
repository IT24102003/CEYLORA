using CeyloraAPI.Data;
using CeyloraAPI.DTOs;
using CeyloraAPI.Models;
using CeyloraAPI.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace CeyloraAPI.Controllers
{
    [ApiController]
    [Route("api/chat")]
    [Authorize]
    public class ChatController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly INotificationService _notificationService;

        public ChatController(AppDbContext context, INotificationService notificationService)
        {
            _context = context;
            _notificationService = notificationService;
        }

        private int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        private string CurrentRole => User.FindFirstValue(ClaimTypes.Role) ?? "";

        // Confirms the current user is allowed to see/send messages on this booking's chat:
        // the tourist who made the booking, the guide assigned to it, or an Admin.
        // Returns (allowed, booking, otherUserId-to-notify).
        private async Task<(bool Allowed, Booking? Booking, int? OtherUserId)> CheckAccessAsync(int bookingId)
        {
            var booking = await _context.Bookings.FirstOrDefaultAsync(b => b.Id == bookingId);
            if (booking == null) return (false, null, null);

            if (CurrentRole == "Admin") return (true, booking, null);

            if (booking.TouristId == CurrentUserId)
            {
                // other side = the assigned guide, if any
                var assignment = await _context.Assignments
                    .Include(a => a.Guide)
                    .FirstOrDefaultAsync(a => a.BookingId == bookingId && a.GuideId != null && a.Status != AssignmentStatus.Cancelled);
                return (true, booking, assignment?.Guide?.UserId);
            }

            var guide = await _context.Guides.FirstOrDefaultAsync(g => g.UserId == CurrentUserId);
            if (guide != null)
            {
                var isAssigned = await _context.Assignments.AnyAsync(a =>
                    a.BookingId == bookingId && a.GuideId == guide.Id && a.Status != AssignmentStatus.Cancelled);
                if (isAssigned) return (true, booking, booking.TouristId);
            }

            return (false, booking, null);
        }

        // GET: api/chat/{bookingId}/messages
        // Returns the full conversation, oldest first, and marks the other side's messages as read.
        [HttpGet("{bookingId}/messages")]
        public async Task<IActionResult> GetMessages(int bookingId)
        {
            var (allowed, booking, _) = await CheckAccessAsync(bookingId);
            if (booking == null) return NotFound(new { message = "Booking not found." });
            if (!allowed) return Forbid();

            var messages = await _context.ChatMessages
                .Where(m => m.BookingId == bookingId)
                .OrderBy(m => m.SentAt)
                .ToListAsync();

            var unreadFromOthers = messages.Where(m => m.SenderId != CurrentUserId && !m.IsRead).ToList();
            if (unreadFromOthers.Count > 0)
            {
                foreach (var m in unreadFromOthers) m.IsRead = true;
                await _context.SaveChangesAsync();
            }

            var result = messages.Select(m => new
            {
                id = m.Id,
                bookingId = m.BookingId,
                senderId = m.SenderId,
                senderRole = m.SenderRole,
                isMine = m.SenderId == CurrentUserId,
                message = m.Message,
                isRead = m.IsRead,
                sentAt = m.SentAt
            });

            return Ok(result);
        }

        // POST: api/chat/{bookingId}/messages
        [HttpPost("{bookingId}/messages")]
        public async Task<IActionResult> SendMessage(int bookingId, SendChatMessageDto dto)
        {
            if (string.IsNullOrWhiteSpace(dto.Message))
                return BadRequest(new { message = "Message cannot be empty." });

            var (allowed, booking, otherUserId) = await CheckAccessAsync(bookingId);
            if (booking == null) return NotFound(new { message = "Booking not found." });
            if (!allowed) return Forbid();

            var message = new ChatMessage
            {
                BookingId = bookingId,
                SenderId = CurrentUserId,
                SenderRole = CurrentRole,
                Message = dto.Message.Trim(),
                IsRead = false,
                SentAt = DateTime.UtcNow
            };
            _context.ChatMessages.Add(message);
            await _context.SaveChangesAsync();

            if (otherUserId.HasValue)
            {
                await _notificationService.CreateAsync(
                    otherUserId.Value,
                    "New message",
                    $"You have a new chat message about booking #{bookingId}.",
                    NotificationType.ChatMessage);
            }

            return Ok(new
            {
                id = message.Id,
                bookingId = message.BookingId,
                senderId = message.SenderId,
                senderRole = message.SenderRole,
                isMine = true,
                message = message.Message,
                isRead = message.IsRead,
                sentAt = message.SentAt
            });
        }

        // GET: api/chat/threads — every chat thread the current user (Tourist or Guide) is
        // part of, for the "Chats" list screen reached from the home-screen chat icon.
        // Tourist side: identified by the trip/package name, with the guide's name available
        // to show inside the conversation. Guide side: identified by the tourist's name.
        [HttpGet("threads")]
        public async Task<IActionResult> GetThreads()
        {
            if (CurrentRole == "Guide")
            {
                var guide = await _context.Guides.FirstOrDefaultAsync(g => g.UserId == CurrentUserId);
                if (guide == null) return Ok(new List<object>());

                var assignments = await _context.Assignments
                    .Include(a => a.Booking).ThenInclude(b => b.Package)
                    .Include(a => a.Booking).ThenInclude(b => b.Tourist)
                    .Where(a => a.GuideId == guide.Id && a.Status != AssignmentStatus.Cancelled)
                    .ToListAsync();

                var bookingIds = assignments.Select(a => a.BookingId).ToList();
                var lastMessages = await GetLastMessagesAsync(bookingIds);
                var unreadCounts = await GetUnreadCountsAsync(bookingIds);

                var threads = assignments.Select(a =>
                {
                    lastMessages.TryGetValue(a.BookingId, out var lastMsg);
                    unreadCounts.TryGetValue(a.BookingId, out var unread);
                    return new
                    {
                        bookingId = a.BookingId,
                        otherPartyName = a.Booking.Tourist?.Name ?? "Tourist",
                        tripName = a.Booking.Package?.Name ?? a.Booking.CustomTripName ?? a.Booking.CustomTripObjective ?? "Trip",
                        lastMessage = lastMsg?.Message,
                        lastMessageAt = lastMsg?.SentAt,
                        unread
                    };
                })
                .OrderByDescending(t => t.lastMessageAt ?? DateTime.MinValue)
                .ToList();

                return Ok(threads);
            }
            else
            {
                var bookings = await _context.Bookings
                    .Include(b => b.Package)
                    .Where(b => b.TouristId == CurrentUserId)
                    .ToListAsync();
                var bookingIds = bookings.Select(b => b.Id).ToList();

                // Only bookings that actually have a guide assigned have someone to chat with.
                var assignments = await _context.Assignments
                    .Include(a => a.Guide).ThenInclude(g => g!.User)
                    .Where(a => bookingIds.Contains(a.BookingId) && a.GuideId != null && a.Status != AssignmentStatus.Cancelled)
                    .ToListAsync();
                var assignedBookingIds = assignments.Select(a => a.BookingId).ToList();

                var lastMessages = await GetLastMessagesAsync(assignedBookingIds);
                var unreadCounts = await GetUnreadCountsAsync(assignedBookingIds);

                var threads = bookings
                    .Where(b => assignedBookingIds.Contains(b.Id))
                    .Select(b =>
                    {
                        var assignment = assignments.First(a => a.BookingId == b.Id);
                        lastMessages.TryGetValue(b.Id, out var lastMsg);
                        unreadCounts.TryGetValue(b.Id, out var unread);
                        return new
                        {
                            bookingId = b.Id,
                            otherPartyName = assignment.Guide?.User?.Name ?? "Guide",
                            tripName = b.Package?.Name ?? b.CustomTripName ?? b.CustomTripObjective ?? "Trip",
                            lastMessage = lastMsg?.Message,
                            lastMessageAt = lastMsg?.SentAt,
                            unread
                        };
                    })
                    .OrderByDescending(t => t.lastMessageAt ?? DateTime.MinValue)
                    .ToList();

                return Ok(threads);
            }
        }

        private async Task<Dictionary<int, ChatMessage>> GetLastMessagesAsync(List<int> bookingIds)
        {
            if (bookingIds.Count == 0) return new Dictionary<int, ChatMessage>();
            var messages = await _context.ChatMessages
                .Where(m => bookingIds.Contains(m.BookingId))
                .ToListAsync();
            return messages
                .GroupBy(m => m.BookingId)
                .ToDictionary(g => g.Key, g => g.OrderByDescending(m => m.SentAt).First());
        }

        private async Task<Dictionary<int, int>> GetUnreadCountsAsync(List<int> bookingIds)
        {
            if (bookingIds.Count == 0) return new Dictionary<int, int>();
            return await _context.ChatMessages
                .Where(m => bookingIds.Contains(m.BookingId) && m.SenderId != CurrentUserId && !m.IsRead)
                .GroupBy(m => m.BookingId)
                .ToDictionaryAsync(g => g.Key, g => g.Count());
        }

        // GET: api/chat/unread-counts
        // Per-booking unread message counts for every booking the current user (Tourist or Guide) is part of.
        // Used by the app to show a badge on booking/assignment cards without opening each chat.
        [HttpGet("unread-counts")]
        public async Task<IActionResult> GetUnreadCounts()
        {
            List<int> bookingIds;

            if (CurrentRole == "Guide")
            {
                var guide = await _context.Guides.FirstOrDefaultAsync(g => g.UserId == CurrentUserId);
                bookingIds = guide == null
                    ? new List<int>()
                    : await _context.Assignments
                        .Where(a => a.GuideId == guide.Id && a.Status != AssignmentStatus.Cancelled)
                        .Select(a => a.BookingId)
                        .ToListAsync();
            }
            else
            {
                bookingIds = await _context.Bookings
                    .Where(b => b.TouristId == CurrentUserId)
                    .Select(b => b.Id)
                    .ToListAsync();
            }

            var counts = await _context.ChatMessages
                .Where(m => bookingIds.Contains(m.BookingId) && m.SenderId != CurrentUserId && !m.IsRead)
                .GroupBy(m => m.BookingId)
                .Select(g => new { bookingId = g.Key, unread = g.Count() })
                .ToListAsync();

            return Ok(counts);
        }
    }
}
