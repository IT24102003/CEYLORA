using Microsoft.EntityFrameworkCore;
using CeyloraAPI.Models;

namespace CeyloraAPI.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

        public DbSet<User> Users { get; set; }
        public DbSet<Destination> Destinations { get; set; }
        public DbSet<Package> Packages { get; set; }
        public DbSet<PackageDestination> PackageDestinations { get; set; }
        public DbSet<Booking> Bookings { get; set; }
        public DbSet<Itinerary> Itineraries { get; set; }
        public DbSet<ItineraryDay> ItineraryDays { get; set; }
        public DbSet<Guide> Guides { get; set; }
        public DbSet<Vehicle> Vehicles { get; set; }
        public DbSet<VehicleImage> VehicleImages { get; set; }
        public DbSet<Hotel> Hotels { get; set; }
        public DbSet<HotelImage> HotelImages { get; set; }
        public DbSet<HotelBooking> HotelBookings { get; set; }
        public DbSet<Assignment> Assignments { get; set; }
        public DbSet<Review> Reviews { get; set; }
        public DbSet<Payment> Payments { get; set; }
        public DbSet<AgentWorkflow> AgentWorkflows { get; set; }
        public DbSet<AgentExecutionLog> AgentExecutionLogs { get; set; }
    }
}