namespace CeyloraAPI.Services
{
    public interface IDistanceService
    {
        Task<double?> GetDistanceKmAsync(double startLat, double startLon, double endLat, double endLon);
    }
}