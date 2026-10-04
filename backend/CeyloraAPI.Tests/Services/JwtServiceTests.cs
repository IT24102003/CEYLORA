using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using CeyloraAPI.Models;
using CeyloraAPI.Services;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace CeyloraAPI.Tests.Services
{
    public class JwtServiceTests
    {
        // Test-only dummy key/issuer/audience — NEVER the real values from
        // appsettings.Development.json.
        private static IConfiguration BuildTestConfig() =>
            new ConfigurationBuilder()
                .AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Jwt:Key"] = "Test-Only-Dummy-Signing-Key-Not-Real-1234567890",
                    ["Jwt:Issuer"] = "CeyloraTestIssuer",
                    ["Jwt:Audience"] = "CeyloraTestAudience",
                    ["Jwt:ExpiryMinutes"] = "60"
                })
                .Build();

        [Fact]
        public void GenerateToken_ReturnsWellFormedJwt_WithExpectedClaims()
        {
            var jwtService = new JwtService(BuildTestConfig());
            var user = new User
            {
                Id = 42,
                Name = "Test User",
                Email = "test@ceylora.com",
                Role = UserRole.Tourist
            };

            var token = jwtService.GenerateToken(user);

            Assert.False(string.IsNullOrWhiteSpace(token));

            var handler = new JwtSecurityTokenHandler();
            var jwt = handler.ReadJwtToken(token);

            Assert.Equal("42", jwt.Claims.First(c => c.Type == ClaimTypes.NameIdentifier).Value);
            Assert.Equal("Test User", jwt.Claims.First(c => c.Type == ClaimTypes.Name).Value);
            Assert.Equal("test@ceylora.com", jwt.Claims.First(c => c.Type == ClaimTypes.Email).Value);
            Assert.Equal("Tourist", jwt.Claims.First(c => c.Type == ClaimTypes.Role).Value);
            Assert.Equal("CeyloraTestIssuer", jwt.Issuer);
        }

        [Fact]
        public void GenerateToken_ExpiryReflectsConfiguredMinutes()
        {
            var jwtService = new JwtService(BuildTestConfig());
            var user = new User { Id = 1, Name = "A", Email = "a@a.com", Role = UserRole.Admin };

            var before = DateTime.UtcNow;
            var token = jwtService.GenerateToken(user);
            var jwt = new JwtSecurityTokenHandler().ReadJwtToken(token);

            // Configured for 60 minutes; allow a small tolerance window for test execution time.
            var expectedExpiry = before.AddMinutes(60);
            Assert.True(Math.Abs((jwt.ValidTo - expectedExpiry).TotalMinutes) < 1);
        }
    }
}
