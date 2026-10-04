using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CeyloraAPI.Tests.Helpers
{
    // Controllers under test read the logged-in user via User.FindFirstValue(...) /
    // User.IsInRole(...), which only works when the controller has an HttpContext with a
    // ClaimsPrincipal attached — this stands one up the same way the real JWT auth
    // middleware would, without needing a live HTTP pipeline.
    public static class ControllerTestExtensions
    {
        public static void SetUser(this ControllerBase controller, int userId, string role)
        {
            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
                new Claim(ClaimTypes.Role, role)
            };
            var identity = new ClaimsIdentity(claims, "TestAuth");
            var principal = new ClaimsPrincipal(identity);

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = principal }
            };
        }
    }
}
