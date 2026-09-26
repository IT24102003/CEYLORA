using CeyloraAPI.DTOs; 
  
namespace CeyloraAPI.Services 
{ 
    public interface IAssignmentService 
    { 
        Task<AssignmentResultDto> AutoMatchAsync(int bookingId, string region, string? 
preferredLanguage); 
    } 
} 