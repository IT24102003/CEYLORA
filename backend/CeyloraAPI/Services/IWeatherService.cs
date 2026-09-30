namespace CeyloraAPI.Services
{
    public interface IWeatherService
    {
        Task<WeatherResult?> GetForecastAsync(double latitude, double longitude);
        Task<WeatherResult?> GetForecastForDayAsync(double latitude, double longitude, int daysFromNow);
    }

    public class WeatherResult
    {
        public string Description { get; set; } = string.Empty;
        public double TemperatureCelsius { get; set; }
        public string Icon { get; set; } = string.Empty;
        public bool IsRainy { get; set; }
    }
}