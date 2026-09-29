namespace CeyloraAPI.Services
{
    public interface IWeatherService
    {
        Task<WeatherResult?> GetForecastAsync(double latitude, double longitude);
    }

    public class WeatherResult
    {
        public string Description { get; set; } = string.Empty;
        public double TemperatureCelsius { get; set; }
        public string Icon { get; set; } = string.Empty;
        public bool IsRainy { get; set; }
    }
}