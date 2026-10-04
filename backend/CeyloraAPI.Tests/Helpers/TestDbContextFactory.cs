using CeyloraAPI.Data;
using Microsoft.EntityFrameworkCore;

namespace CeyloraAPI.Tests.Helpers
{
    // Every test gets its own brand-new, isolated in-memory database (unique name per call),
    // so tests never see leftover data from another test. This avoids needing a real
    // Postgres connection just to run `dotnet test`.
    public static class TestDbContextFactory
    {
        public static AppDbContext Create()
        {
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString())
                .Options;

            return new AppDbContext(options);
        }
    }
}
