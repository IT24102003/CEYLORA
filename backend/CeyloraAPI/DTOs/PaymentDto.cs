namespace CeyloraAPI.DTOs 
{ 
    public class CreatePaymentDto 
    { 
        public int BookingId { get; set; } 
        public decimal Amount { get; set; } 
    } 
}