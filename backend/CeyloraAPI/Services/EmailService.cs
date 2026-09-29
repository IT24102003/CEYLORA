using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace CeyloraAPI.Services
{
    public class EmailService : IEmailService
    {
        private readonly IConfiguration _config;
        private readonly ILogger<EmailService> _logger;

        public EmailService(IConfiguration config, ILogger<EmailService> logger)
        {
            _config = config;
            _logger = logger;
        }

        private async Task SendEmailAsync(string toEmail, string subject, string htmlBody)
        {
            var host = _config["ExternalServices:EmailSmtp:Host"];
            var port = int.Parse(_config["ExternalServices:EmailSmtp:Port"] ?? "587");
            var username = _config["ExternalServices:EmailSmtp:Username"];
            var appPassword = _config["ExternalServices:EmailSmtp:AppPassword"];

            if (string.IsNullOrEmpty(username) || string.IsNullOrEmpty(appPassword))
            {
                _logger.LogWarning("Email service not configured — skipping send to {Email}", toEmail);
                return;
            }

            var message = new MimeMessage();
            message.From.Add(new MailboxAddress("CEYLORA", username));
            message.To.Add(new MailboxAddress("", toEmail));
            message.Subject = subject;
            message.Body = new TextPart("html") { Text = htmlBody };

            try
            {
                using var client = new SmtpClient();
                await client.ConnectAsync(host, port, SecureSocketOptions.StartTls);
                await client.AuthenticateAsync(username, appPassword);
                await client.SendAsync(message);
                await client.DisconnectAsync(true);
            }
            catch (Exception ex)
            {
                // Safe failure — never let an email error break the calling request
                _logger.LogError(ex, "Failed to send email to {Email}", toEmail);
            }
        }

        public Task SendWelcomeEmailAsync(string toEmail, string name)
        {
            var html = $@"
                <h2>Welcome to CEYLORA, {name}!</h2>
                <p>Thank you for joining CEYLORA — your gateway to exploring Sri Lanka.</p>
                <p>Start browsing destinations, packages and let our AI trip planner help you build the perfect itinerary.</p>";
            return SendEmailAsync(toEmail, "Welcome to CEYLORA!", html);
        }

        public Task SendBookingApprovedEmailAsync(string toEmail, string name, int bookingId)
        {
            var html = $@"
                <h2>Great news, {name}!</h2>
                <p>Your booking <strong>#{bookingId}</strong> has been reviewed and approved.</p>
                <p>You can now proceed with payment to confirm your trip.</p>";
            return SendEmailAsync(toEmail, $"Booking #{bookingId} Approved — CEYLORA", html);
        }

        public Task SendPaymentConfirmationEmailAsync(string toEmail, string name, int bookingId, decimal amount)
        {
            var html = $@"
                <h2>Payment Confirmed</h2>
                <p>Hi {name},</p>
                <p>We've received your payment of <strong>LKR {amount}</strong> for booking <strong>#{bookingId}</strong>.</p>
                <p>Your trip is now fully confirmed. We wish you a wonderful journey with CEYLORA!</p>";
            return SendEmailAsync(toEmail, $"Payment Confirmed — Booking #{bookingId}", html);
        }
    }
}