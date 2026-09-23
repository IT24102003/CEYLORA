using CeyloraAPI.Models;

namespace CeyloraAPI.Services
{
    public interface IJwtService
    {
        string GenerateToken(User user);
    }
}