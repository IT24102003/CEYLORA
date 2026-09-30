namespace CeyloraAPI.Services
{
    public interface INotificationService
    {
        Task CreateAsync(int userId, string title, string message, string type);
    }
}
