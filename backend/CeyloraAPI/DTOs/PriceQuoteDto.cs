namespace CeyloraAPI.DTOs
{
    public class PriceQuoteRequestDto
    {
        public int GroupSize { get; set; }
        public DateTime TravelDate { get; set; }
    }

    public class PriceQuoteResponseDto
    {
        public decimal BasePrice { get; set; }
        public decimal SeasonMultiplier { get; set; }
        public decimal GroupDiscount { get; set; }
        public decimal FinalPricePerPerson { get; set; }
        public decimal TotalPrice { get; set; }
        public string PricingNote { get; set; } = string.Empty;
    }
}