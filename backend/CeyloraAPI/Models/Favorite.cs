namespace CeyloraAPI.Models
{
    // What kind of item a Favorite points to. Kept as a simple string enum-like value
    // (not an FK) so ONE table covers Destinations, Packages, Hotels, Guides and Vehicles.
    public static class FavoriteItemType
    {
        public const string Destination = "Destination";
        public const string Package = "Package";
        public const string Hotel = "Hotel";
        public const string Guide = "Guide";
        public const string Vehicle = "Vehicle";
    }

    public class Favorite
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public User User { get; set; } = null!;
        public string ItemType { get; set; } = string.Empty; // "Destination" | "Package" | "Hotel" | "Guide" | "Vehicle"
        public int ItemId { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
