using CeyloraAPI.Models;
using Microsoft.EntityFrameworkCore;

namespace CeyloraAPI.Data
{
    public static class DbInitializer
    {
        public static async Task SeedAsync(AppDbContext context)
        {
            await context.Database.EnsureCreatedAsync();

            if (await context.Users.AnyAsync()) return; // Database already seeded

            // 1. Seed Default Users
            var adminUser = new User
            {
                Name = "Admin Staff",
                Email = "admin@ceylora.lk",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Admin@123"),
                Role = UserRole.Admin,
                CreatedAt = DateTime.UtcNow
            };

            var touristUser = new User
            {
                Name = "Kasun Perera",
                Email = "kasun@gmail.com",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Tourist@123"),
                Role = UserRole.Tourist,
                CreatedAt = DateTime.UtcNow
            };

            var guideUser = new User
            {
                Name = "Nimal Silva",
                Email = "nimal.guide@ceylora.lk",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Guide@123"),
                Role = UserRole.Guide,
                CreatedAt = DateTime.UtcNow
            };

            context.Users.AddRange(adminUser, touristUser, guideUser);
            await context.SaveChangesAsync();

            // 2. Seed Destinations
            var sigiriya = new Destination
            {
                Name = "Sigiriya Rock Fortress",
                Region = "Cultural Triangle",
                Category = "Historical & Heritage",
                Description = "Ancient palace rock fortress with 5th-century frescoes and water gardens.",
                Latitude = 7.9570,
                Longitude = 80.7603,
                ImageUrl = "https://images.unsplash.com/photo-1586861635167-e5223aadc9fe?w=800"
            };

            var ella = new Destination
            {
                Name = "Nine Arch Bridge Ella",
                Region = "Hill Country",
                Category = "Nature & Adventure",
                Description = "Iconic colonial-era viaduct bridge surrounded by lush green tea gardens.",
                Latitude = 6.8768,
                Longitude = 81.0608,
                ImageUrl = "https://images.unsplash.com/photo-1546708973-b339540b5162?w=800"
            };

            var kandy = new Destination
            {
                Name = "Temple of the Sacred Tooth Relic",
                Region = "Central Province",
                Category = "Culture & Heritage",
                Description = "Venerated Buddhist temple in Kandy housing the sacred tooth relic of Buddha.",
                Latitude = 7.2936,
                Longitude = 80.6413,
                ImageUrl = "https://images.unsplash.com/photo-1588598050720-333d02f5a6b7?w=800"
            };

            var mirissa = new Destination
            {
                Name = "Mirissa Beach & Coconut Tree Hill",
                Region = "Southern Coast",
                Category = "Beach & Relaxation",
                Description = "Famous golden sandy beach renowned for whale watching and breathtaking sunsets.",
                Latitude = 5.9483,
                Longitude = 80.4716,
                ImageUrl = "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800"
            };

            context.Destinations.AddRange(sigiriya, ella, kandy, mirissa);
            await context.SaveChangesAsync();

            // 3. Seed Hotels
            var hotel1 = new Hotel
            {
                Name = "Heritance Kandalama",
                Region = "Cultural Triangle",
                Address = "Kandalama, Dambulla",
                StarRating = 5,
                PricePerNight = 35000m,
                RoomsAvailable = 15,
                Description = "Eco-luxury hotel designed by Geoffrey Bawa overlooking Sigiriya rock.",
                ImageUrl = "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800"
            };

            var hotel2 = new Hotel
            {
                Name = "Grand Hotel Nuwara Eliya",
                Region = "Hill Country",
                Address = "Grand Hotel Rd, Nuwara Eliya",
                StarRating = 4,
                PricePerNight = 24000m,
                RoomsAvailable = 20,
                Description = "Colonial-style heritage hotel surrounded by manicured lawns and tea plantations.",
                ImageUrl = "https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800"
            };

            var hotel3 = new Hotel
            {
                Name = "Cinnamon Citadel Kandy",
                Region = "Central Province",
                Address = "Srimath Kudarathwatta Mawatha, Kandy",
                StarRating = 4,
                PricePerNight = 18000m,
                RoomsAvailable = 25,
                Description = "Scenic riverside resort along the Mahaweli River in Kandy.",
                ImageUrl = "https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800"
            };

            context.Hotels.AddRange(hotel1, hotel2, hotel3);
            await context.SaveChangesAsync();

            // 4. Seed Packages
            var pkg1 = new Package
            {
                Name = "Hill Country & Tea Estate Discovery",
                Description = "3-day scenic journey through Kandy, Nuwara Eliya, and Ella.",
                BasePrice = 45000m,
                DurationDays = 3,
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            };

            var pkg2 = new Package
            {
                Name = "Ancient Kingdom & Cultural Heritage Tour",
                Description = "2-day trip exploring Sigiriya Rock and Dambulla cave temples.",
                BasePrice = 30000m,
                DurationDays = 2,
                IsPublished = true,
                CreatedAt = DateTime.UtcNow
            };

            context.Packages.AddRange(pkg1, pkg2);
            await context.SaveChangesAsync();

            // Link package destinations
            context.PackageDestinations.AddRange(
                new PackageDestination { PackageId = pkg1.Id, DestinationId = kandy.Id, DayNumber = 1 },
                new PackageDestination { PackageId = pkg1.Id, DestinationId = ella.Id, DayNumber = 2 },
                new PackageDestination { PackageId = pkg2.Id, DestinationId = sigiriya.Id, DayNumber = 1 }
            );
            await context.SaveChangesAsync();
        }
    }
}
