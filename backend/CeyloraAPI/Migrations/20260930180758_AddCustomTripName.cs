using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CeyloraAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddCustomTripName : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "CustomTripName",
                table: "Bookings",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CustomTripName",
                table: "Bookings");
        }
    }
}
