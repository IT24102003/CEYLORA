using CeyloraAPI.Controllers;
using CeyloraAPI.DTOs;
using CeyloraAPI.Models;
using CeyloraAPI.Services;
using CeyloraAPI.Tests.Helpers;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace CeyloraAPI.Tests.Controllers
{
    public class AuthControllerTests
    {
        // Builds a fresh AuthController wired to its own isolated in-memory database and
        // mocked side-effect dependencies (email/notifications/file-storage), exactly like
        // the AuthController constructor expects, but with nothing real going out.
        private static AuthController BuildController(
            out Mock<IEmailService> emailMock,
            out Mock<INotificationService> notificationMock)
        {
            var context = TestDbContextFactory.Create();
            var jwtService = new FakeJwtService();
            emailMock = new Mock<IEmailService>();
            notificationMock = new Mock<INotificationService>();
            var envMock = new Mock<IWebHostEnvironment>();
            envMock.Setup(e => e.WebRootPath).Returns("/tmp/wwwroot-test");

            return new AuthController(
                context, jwtService, emailMock.Object, notificationMock.Object, envMock.Object);
        }

        // A dummy token generator so these tests don't depend on JwtService/real config
        // (JwtService has its own dedicated tests).
        private class FakeJwtService : IJwtService
        {
            public string GenerateToken(User user) => $"fake-token-for-{user.Id}";
        }

        private static RegisterDto ValidTouristDto(string email = "tourist@ceylora.com") => new()
        {
            Name = "Nimal Perera",
            Email = email,
            Password = "password123",
            Role = UserRole.Tourist,
            Country = "Sri Lanka",
            MobileNumber = "0771234567"
        };

        [Fact]
        public async Task Register_NewTourist_ReturnsOkWithTokenAndCreatesUser()
        {
            var controller = BuildController(out var emailMock, out var notificationMock);
            var dto = ValidTouristDto();

            var result = await controller.Register(dto);

            var okResult = Assert.IsType<OkObjectResult>(result.Result);
            var response = Assert.IsType<AuthResponseDto>(okResult.Value);
            Assert.Equal(dto.Email, response.Email);
            Assert.Equal("Tourist", response.Role);
            Assert.False(string.IsNullOrWhiteSpace(response.Token));
            Assert.True(response.IsVerified);

            emailMock.Verify(e => e.SendWelcomeEmailAsync(dto.Email, dto.Name), Times.Once);
            notificationMock.Verify(n => n.CreateAsync(
                response.UserId, It.IsAny<string>(), It.IsAny<string>(), NotificationType.Welcome), Times.Once);
        }

        [Fact]
        public async Task Register_DuplicateEmail_ReturnsBadRequest()
        {
            var controller = BuildController(out _, out _);
            var dto = ValidTouristDto("duplicate@ceylora.com");

            var first = await controller.Register(dto);
            Assert.IsType<OkObjectResult>(first.Result);

            // Same email again, different name — must be rejected.
            var second = await controller.Register(ValidTouristDto("duplicate@ceylora.com"));

            var badRequest = Assert.IsType<BadRequestObjectResult>(second.Result);
            Assert.Contains("already registered", badRequest.Value!.ToString());
        }

        [Theory]
        [InlineData(UserRole.Guide)]
        [InlineData(UserRole.VehicleOwner)]
        public async Task Register_GuideOrVehicleOwnerRole_IsRejected_MustUseDedicatedForm(UserRole role)
        {
            var controller = BuildController(out _, out _);
            var dto = ValidTouristDto();
            dto.Role = role;

            var result = await controller.Register(dto);

            var badRequest = Assert.IsType<BadRequestObjectResult>(result.Result);
            Assert.Contains("Guide or Vehicle Owner registration form", badRequest.Value!.ToString());
        }

        [Fact]
        public async Task Login_UnknownEmail_ReturnsUnauthorized()
        {
            var controller = BuildController(out _, out _);

            var result = await controller.Login(new LoginDto { Email = "nobody@ceylora.com", Password = "whatever" });

            Assert.IsType<UnauthorizedObjectResult>(result.Result);
        }

        [Fact]
        public async Task Login_WrongPassword_ReturnsUnauthorized()
        {
            var controller = BuildController(out _, out _);
            var dto = ValidTouristDto("wrongpass@ceylora.com");
            await controller.Register(dto);

            var result = await controller.Login(new LoginDto { Email = dto.Email, Password = "not-the-right-password" });

            Assert.IsType<UnauthorizedObjectResult>(result.Result);
        }

        [Fact]
        public async Task Login_CorrectCredentials_ReturnsOkWithToken()
        {
            var controller = BuildController(out _, out _);
            var dto = ValidTouristDto("correctpass@ceylora.com");
            await controller.Register(dto);

            var result = await controller.Login(new LoginDto { Email = dto.Email, Password = dto.Password });

            var okResult = Assert.IsType<OkObjectResult>(result.Result);
            var response = Assert.IsType<AuthResponseDto>(okResult.Value);
            Assert.Equal(dto.Email, response.Email);
            Assert.False(string.IsNullOrWhiteSpace(response.Token));
        }
    }
}
