using CeyloraAPI.Controllers;
using CeyloraAPI.DTOs;
using CeyloraAPI.Models;
using CeyloraAPI.Tests.Helpers;
using Microsoft.AspNetCore.Mvc;
using Xunit;

namespace CeyloraAPI.Tests.Controllers
{
    public class VehiclesControllerTests
    {
        private const int OwnerId = 100;
        private const int OtherOwnerId = 200;
        private const int AdminId = 1;

        private static (CeyloraAPI.Data.AppDbContext Context, Vehicle Vehicle) SeedVehicle()
        {
            var context = TestDbContextFactory.Create();

            var owner = new User { Id = OwnerId, Name = "Kamal", Email = "kamal@ceylora.com", Role = UserRole.VehicleOwner };
            context.Users.Add(owner);

            var vehicle = new Vehicle
            {
                Id = 1,
                OperatorId = OwnerId,
                Type = "Van",
                Name = "Toyota HiAce",
                ManufacturerYear = 2020,
                Capacity = 8,
                Region = "Kandy",
                PricePerKm = 180m,
                IsAvailable = true
            };
            context.Vehicles.Add(vehicle);
            context.SaveChanges();

            return (context, vehicle);
        }

        // ---- UpdateDetails: ownership boundary (the part the earlier VehicleOwnerUpdateDto
        // feature depends on) ----

        [Fact]
        public async Task UpdateDetails_OwningVehicleOwner_UpdatesAllowedFieldsOnly()
        {
            var (context, vehicle) = SeedVehicle();
            var controller = new VehiclesController(context);
            controller.SetUser(OwnerId, "VehicleOwner");

            var dto = new VehicleOwnerUpdateDto
            {
                Name = "Toyota HiAce (Updated)",
                ManufacturerYear = 2021,
                Capacity = 10,
                Region = "Colombo"
            };

            var result = await controller.UpdateDetails(vehicle.Id, dto);

            Assert.IsType<NoContentResult>(result);
            var updated = await context.Vehicles.FindAsync(vehicle.Id);
            Assert.Equal("Toyota HiAce (Updated)", updated!.Name);
            Assert.Equal(10, updated.Capacity);
            Assert.Equal("Colombo", updated.Region);
            // Type and PricePerKm are not in VehicleOwnerUpdateDto, so they must stay untouched.
            Assert.Equal("Van", updated.Type);
            Assert.Equal(180m, updated.PricePerKm);
        }

        [Fact]
        public async Task UpdateDetails_NonOwningVehicleOwner_ReturnsForbid()
        {
            var (context, vehicle) = SeedVehicle();
            var controller = new VehiclesController(context);
            controller.SetUser(OtherOwnerId, "VehicleOwner"); // a different vehicle owner, not the real owner

            var dto = new VehicleOwnerUpdateDto { Name = "Hijacked", Capacity = 1, Region = "Galle" };

            var result = await controller.UpdateDetails(vehicle.Id, dto);

            Assert.IsType<ForbidResult>(result);
            var unchanged = await context.Vehicles.FindAsync(vehicle.Id);
            Assert.Equal("Toyota HiAce", unchanged!.Name); // untouched
        }

        [Fact]
        public async Task UpdateDetails_Admin_CanEditAnyVehicle()
        {
            var (context, vehicle) = SeedVehicle();
            var controller = new VehiclesController(context);
            controller.SetUser(AdminId, "Admin");

            var dto = new VehicleOwnerUpdateDto { Name = "Admin Edited", Capacity = 12, Region = "Galle" };

            var result = await controller.UpdateDetails(vehicle.Id, dto);

            Assert.IsType<NoContentResult>(result);
        }

        [Fact]
        public async Task UpdateDetails_VehicleDoesNotExist_ReturnsNotFound()
        {
            var (context, _) = SeedVehicle();
            var controller = new VehiclesController(context);
            controller.SetUser(OwnerId, "VehicleOwner");

            var result = await controller.UpdateDetails(9999, new VehicleOwnerUpdateDto { Capacity = 4, Region = "Galle" });

            Assert.IsType<NotFoundObjectResult>(result);
        }

        // ---- ToggleAvailability: business rule — can't go back to "Available" while on an
        // active (Confirmed/OnGoing) trip. This is the "business-specific operation" test. ----

        [Fact]
        public async Task ToggleAvailability_CannotEnable_WhileVehicleHasActiveConfirmedTrip()
        {
            var (context, vehicle) = SeedVehicle();
            vehicle.IsAvailable = false;

            var tourist = new User { Id = 300, Name = "Tourist", Email = "t@ceylora.com", Role = UserRole.Tourist };
            context.Users.Add(tourist);
            var booking = new Booking { Id = 1, TouristId = tourist.Id, Tourist = tourist, Status = BookingStatus.Confirmed, GroupSize = 2 };
            context.Bookings.Add(booking);
            context.Assignments.Add(new Assignment { Id = 1, BookingId = booking.Id, Booking = booking, VehicleId = vehicle.Id });
            await context.SaveChangesAsync();

            var controller = new VehiclesController(context);
            controller.SetUser(OwnerId, "VehicleOwner");

            var result = await controller.ToggleAvailability(vehicle.Id, isAvailable: true);

            var badRequest = Assert.IsType<BadRequestObjectResult>(result);
            Assert.Contains("active/on-going trip", badRequest.Value!.ToString());
            var unchanged = await context.Vehicles.FindAsync(vehicle.Id);
            Assert.False(unchanged!.IsAvailable);
        }

        [Fact]
        public async Task ToggleAvailability_CanEnable_WhenNoActiveTrip()
        {
            var (context, vehicle) = SeedVehicle();
            vehicle.IsAvailable = false;
            await context.SaveChangesAsync();

            var controller = new VehiclesController(context);
            controller.SetUser(OwnerId, "VehicleOwner");

            var result = await controller.ToggleAvailability(vehicle.Id, isAvailable: true);

            Assert.IsType<NoContentResult>(result);
            var updated = await context.Vehicles.FindAsync(vehicle.Id);
            Assert.True(updated!.IsAvailable);
        }

        [Fact]
        public async Task ToggleAvailability_CanAlwaysDisable_EvenWithActiveTrip()
        {
            var (context, vehicle) = SeedVehicle();

            var tourist = new User { Id = 301, Name = "Tourist2", Email = "t2@ceylora.com", Role = UserRole.Tourist };
            context.Users.Add(tourist);
            var booking = new Booking { Id = 2, TouristId = tourist.Id, Tourist = tourist, Status = BookingStatus.OnGoing, GroupSize = 2 };
            context.Bookings.Add(booking);
            context.Assignments.Add(new Assignment { Id = 2, BookingId = booking.Id, Booking = booking, VehicleId = vehicle.Id });
            await context.SaveChangesAsync();

            var controller = new VehiclesController(context);
            controller.SetUser(OwnerId, "VehicleOwner");

            var result = await controller.ToggleAvailability(vehicle.Id, isAvailable: false);

            Assert.IsType<NoContentResult>(result);
        }

        [Fact]
        public async Task GetById_UnknownVehicle_ReturnsNotFound()
        {
            var (context, _) = SeedVehicle();
            var controller = new VehiclesController(context);

            var result = await controller.GetById(9999);

            Assert.IsType<NotFoundObjectResult>(result.Result);
        }
    }
}
