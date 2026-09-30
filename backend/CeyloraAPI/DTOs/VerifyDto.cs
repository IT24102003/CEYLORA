namespace CeyloraAPI.DTOs
{
    // Used by the admin verification endpoints for both Guides and Vehicle Owners.
    public class VerifyDto
    {
        public bool Approve { get; set; }
        public string? Note { get; set; }
    }
}
