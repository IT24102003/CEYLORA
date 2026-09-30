namespace CeyloraAPI.DTOs
{
    public class CreateFavoriteDto
    {
        public string ItemType { get; set; } = string.Empty; // "Destination" | "Package" | "Hotel" | "Guide" | "Vehicle"
        public int ItemId { get; set; }
    }
}
