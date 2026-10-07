using CeyloraAPI.Controllers;
using CeyloraAPI.Data;
using CeyloraAPI.DTOs;
using CeyloraAPI.Models;
using CeyloraAPI.Services;
using CeyloraAPI.Tests.Helpers;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace CeyloraAPI.Tests.Controllers
{
	// Covers the business rules of the sandbox payment flow: the amount must equal the
	// booking total, a valid payment marks the booking as paid, and a rejected payment
	// leaves no record behind. Email and notification services are mocked so the tests
	// need no SMTP server and no database other than the EF Core InMemory provider.
	public class PaymentsControllerTests
	{
		private const int TouristId = 10;
		private const decimal BookingTotal = 45000m;

		private static (AppDbContext Context, Booking Booking, PaymentsController Controller,
			Mock<INotificationService> Notifications) Arrange()
		{
			var context = TestDbContextFactory.Create();

			var tourist = new User
			{
				Id = TouristId,
				Name = "Nimal",
				Email = "nimal@ceylora.com",
				Role = UserRole.Tourist
			};
			context.Users.Add(tourist);

			var booking = new Booking
			{
				Id = 1,
				TouristId = TouristId,
				GroupSize = 4,
				TotalPrice = BookingTotal,
				IsPaid = false
			};
			context.Bookings.Add(booking);
			context.SaveChanges();

			var email = new Mock<IEmailService>();
			var notifications = new Mock<INotificationService>();
			var controller = new PaymentsController(context, email.Object, notifications.Object);
			controller.SetUser(TouristId, "Tourist");

			return (context, booking, controller, notifications);
		}

		[Fact]
		public async Task Create_AmountDoesNotMatchBookingTotal_ReturnsBadRequestAndStoresNoPayment()
		{
			var (context, booking, controller, _) = Arrange();

			var result = await controller.Create(new CreatePaymentDto { BookingId = booking.Id, Amount = BookingTotal - 1m });

			Assert.IsType<BadRequestObjectResult>(result.Result);
			Assert.Empty(context.Payments);
			Assert.False(context.Bookings.Single().IsPaid);
		}

		[Fact]
		public async Task Create_UnknownBooking_ReturnsNotFound()
		{
			var (context, _, controller, _) = Arrange();

			var result = await controller.Create(new CreatePaymentDto { BookingId = 999, Amount = BookingTotal });

			Assert.IsType<NotFoundObjectResult>(result.Result);
			Assert.Empty(context.Payments);
		}

		[Fact]
		public async Task Create_MatchingAmount_CreatesSuccessPaymentAndMarksBookingPaid()
		{
			var (context, booking, controller, notifications) = Arrange();

			var result = await controller.Create(new CreatePaymentDto { BookingId = booking.Id, Amount = BookingTotal });

			Assert.IsType<CreatedAtActionResult>(result.Result);
			var payment = Assert.Single(context.Payments);
			Assert.Equal(PaymentStatus.Success, payment.Status);
			Assert.Equal(BookingTotal, payment.Amount);
			Assert.Equal("Sandbox", payment.Provider);
			Assert.True(context.Bookings.Single().IsPaid);
			notifications.Verify(n => n.CreateAsync(TouristId, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>()), Times.Once);
		}

		[Fact]
		public async Task GetByBooking_ReturnsOnlyPaymentsOfThatBooking()
		{
			var (context, booking, controller, _) = Arrange();
			context.Bookings.Add(new Booking { Id = 2, TouristId = TouristId, TotalPrice = 1000m });
			context.Payments.Add(new Payment { BookingId = booking.Id, Amount = BookingTotal, Status = PaymentStatus.Success });
			context.Payments.Add(new Payment { BookingId = 2, Amount = 1000m, Status = PaymentStatus.Success });
			context.SaveChanges();

			var result = await controller.GetByBooking(booking.Id);

			var ok = Assert.IsType<OkObjectResult>(result.Result);
			var list = Assert.IsAssignableFrom<List<Payment>>(ok.Value);
			Assert.Single(list);
			Assert.Equal(booking.Id, list[0].BookingId);
		}
	}
}
