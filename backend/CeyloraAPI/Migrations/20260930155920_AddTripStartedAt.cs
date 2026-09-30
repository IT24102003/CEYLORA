using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CeyloraAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddTripStartedAt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "TripStartedAt",
                table: "Bookings",
                type: "timestamp without time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "TripStartedAt",
                table: "Bookings");
        }
    }
}
