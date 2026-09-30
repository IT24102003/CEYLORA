using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace CeyloraAPI.Migrations
{
    /// <inheritdoc />
    public partial class AdminPanelUpgrade : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "MaxPeople",
                table: "Packages",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "SuggestedGuideId",
                table: "Packages",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "SuggestedVehicleId",
                table: "Packages",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "GroupSize",
                table: "Bookings",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "PackageHotels",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    PackageId = table.Column<int>(type: "integer", nullable: false),
                    HotelId = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PackageHotels", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PackageHotels_Hotels_HotelId",
                        column: x => x.HotelId,
                        principalTable: "Hotels",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_PackageHotels_Packages_PackageId",
                        column: x => x.PackageId,
                        principalTable: "Packages",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Packages_SuggestedGuideId",
                table: "Packages",
                column: "SuggestedGuideId");

            migrationBuilder.CreateIndex(
                name: "IX_Packages_SuggestedVehicleId",
                table: "Packages",
                column: "SuggestedVehicleId");

            migrationBuilder.CreateIndex(
                name: "IX_PackageHotels_HotelId",
                table: "PackageHotels",
                column: "HotelId");

            migrationBuilder.CreateIndex(
                name: "IX_PackageHotels_PackageId",
                table: "PackageHotels",
                column: "PackageId");

            migrationBuilder.AddForeignKey(
                name: "FK_Packages_Guides_SuggestedGuideId",
                table: "Packages",
                column: "SuggestedGuideId",
                principalTable: "Guides",
                principalColumn: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Packages_Vehicles_SuggestedVehicleId",
                table: "Packages",
                column: "SuggestedVehicleId",
                principalTable: "Vehicles",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Packages_Guides_SuggestedGuideId",
                table: "Packages");

            migrationBuilder.DropForeignKey(
                name: "FK_Packages_Vehicles_SuggestedVehicleId",
                table: "Packages");

            migrationBuilder.DropTable(
                name: "PackageHotels");

            migrationBuilder.DropIndex(
                name: "IX_Packages_SuggestedGuideId",
                table: "Packages");

            migrationBuilder.DropIndex(
                name: "IX_Packages_SuggestedVehicleId",
                table: "Packages");

            migrationBuilder.DropColumn(
                name: "MaxPeople",
                table: "Packages");

            migrationBuilder.DropColumn(
                name: "SuggestedGuideId",
                table: "Packages");

            migrationBuilder.DropColumn(
                name: "SuggestedVehicleId",
                table: "Packages");

            migrationBuilder.DropColumn(
                name: "GroupSize",
                table: "Bookings");
        }
    }
}
