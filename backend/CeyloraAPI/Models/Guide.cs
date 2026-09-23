namespace CeyloraAPI.Models
{
    public class Guide
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public User User { get; set; } = null!;
        public string? Languages { get; set; }
        public string Region { get; set; } = string.Empty;
        public double Rating { get; set; } = 0;
        public bool IsAvailable { get; set; } = true;
    }
}