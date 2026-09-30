using CeyloraAPI.Data;
using CeyloraAPI.Models;

namespace CeyloraAPI.Services
{
    // Creates the in-app Notification row shown in the Flutter app's bell/notifications screen.
    // This is separate from IEmailService (which sends the actual email) — the two are called
    // together at each trigger point (welcome, booking approved, payment confirmed, etc.).
    public class NotificationService : INotificationService
    {
        private readonly AppDbContext _context;

        public NotificationService(AppDbContext context)
        {
            _context = context;
        }

        public async Task CreateAsync(int userId, string title, string message, string type)
        {
            _context.Notifications.Add(new Notification
            {
                UserId = userId,
                Title = title,
                Message = message,
                Type = type,
                IsRead = false,
                CreatedAt = DateTime.UtcNow
            });
            await _context.SaveChangesAsync();
        }
    }
}
