namespace CeyloraAPI.Services
{
    public interface IEmailService
    {
        Task SendWelcomeEmailAsync(string toEmail, string name);
        Task SendBookingApprovedEmailAsync(string toEmail, string name, int bookingId);
        Task SendPaymentConfirmationEmailAsync(string toEmail, string name, int bookingId, decimal amount);
    }
}