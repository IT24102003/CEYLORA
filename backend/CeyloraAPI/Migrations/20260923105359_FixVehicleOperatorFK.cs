using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CeyloraAPI.Migrations
{
    /// <inheritdoc />
    public partial class FixVehicleOperatorFK : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Vehicles_Users_Operator_Id",
                table: "Vehicles");

            migrationBuilder.DropIndex(
                name: "IX_Vehicles_Operator_Id",
                table: "Vehicles");

            migrationBuilder.DropColumn(
                name: "Operator_Id",
                table: "Vehicles");

            migrationBuilder.CreateIndex(
                name: "IX_Vehicles_OperatorId",
                table: "Vehicles",
                column: "OperatorId");

            migrationBuilder.AddForeignKey(
                name: "FK_Vehicles_Users_OperatorId",
                table: "Vehicles",
                column: "OperatorId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Vehicles_Users_OperatorId",
                table: "Vehicles");

            migrationBuilder.DropIndex(
                name: "IX_Vehicles_OperatorId",
                table: "Vehicles");

            migrationBuilder.AddColumn<int>(
                name: "Operator_Id",
                table: "Vehicles",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateIndex(
                name: "IX_Vehicles_Operator_Id",
                table: "Vehicles",
                column: "Operator_Id");

            migrationBuilder.AddForeignKey(
                name: "FK_Vehicles_Users_Operator_Id",
                table: "Vehicles",
                column: "Operator_Id",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
