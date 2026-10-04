using Microsoft.EntityFrameworkCore;
using CeyloraAPI.Data;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using CeyloraAPI.Services;

AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;
    });

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowClientApps", policy =>
    {
        // Allow any origin: the admin panel/mobile app may be running on
        // localhost (dev) or a deployed domain (prod), and this API never
        // uses cookies for auth (JWT is sent as an Authorization header), so
        // a wildcard origin carries no credential-theft risk here.
        policy.AllowAnyOrigin()
             .AllowAnyHeader()
             .AllowAnyMethod();
    });
});

builder.Services.AddEndpointsApiExplorer();

// Swagger with JWT support
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo
    {
        Title = "CeyloraAPI",
        Version = "v1"
    });

    options.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.ApiKey,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "Enter 'Bearer' [space] and then your token. Example: \"Bearer eyJhbGciOi...\""
    });

    options.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// Register AppDbContext with PostgreSQL
// EnableRetryOnFailure: Supabase's free-tier (Nano compute) pooler occasionally
// stalls a query for several seconds under load ("Timeout during reading attempt",
// a transient failure per Npgsql's own classification) even when the connection
// pool itself isn't exhausted. Retrying a few times with a short backoff lets
// those recover instead of surfacing as a 500 to the client.
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        npgsqlOptions => npgsqlOptions.EnableRetryOnFailure(
            // Kept short on purpose: the frontend gives up on a request after 15s
            // (see api.js), so a retry chain here has to resolve well inside that,
            // not after it — a retry that finishes 20s after the browser already
            // cancelled helps no one. Paired with a lower Command Timeout in the
            // connection string, 2 retries x up to 2s backoff leaves comfortable
            // room for a quick attempt + one retry to land inside the client's
            // window.
            maxRetryCount: 2,
            maxRetryDelay: TimeSpan.FromSeconds(2),
            errorCodesToAdd: null)));

// JWT Authentication
var jwtKey = builder.Configuration["Jwt:Key"]!;
builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = builder.Configuration["Jwt:Issuer"],
        ValidAudience = builder.Configuration["Jwt:Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey))
    };
});

builder.Services.AddAuthorization();

// Register application services
builder.Services.AddScoped<IJwtService, JwtService>();
builder.Services.AddScoped<IPricingService, PricingService>();
builder.Services.AddScoped<IPricingService, PricingService>();
builder.Services.AddScoped<IHotelService, HotelService>();
builder.Services.AddScoped<IBookingService, BookingService>();
builder.Services.AddScoped<IAssignmentService, AssignmentService>();
builder.Services.AddHttpClient<IAgenticAIClient, AgenticAIClient>();
builder.Services.AddHttpClient<IWeatherService, WeatherService>();
builder.Services.AddHttpClient<IDistanceService, DistanceService>();
builder.Services.AddScoped<IEmailService, EmailService>();
builder.Services.AddScoped<INotificationService, NotificationService>();

var app = builder.Build();

app.UseCors("AllowClientApps");
app.UseAuthentication();
app.UseAuthorization();

// Configure the HTTP request pipeline.
// Swagger is left on in every environment (not just Development) so the
// deployed API has a visible, interactive API surface for demo/grading
// purposes — there's no sensitive data exposed by the schema itself.
app.UseSwagger();
app.UseSwaggerUI();

app.UseStaticFiles();
// 🔥 Removed app.UseHttpsRedirection() — it was forcing every plain-HTTP
// request to redirect to https://localhost:7267. That redirect works fine
// from Chrome (same machine, "localhost" means the dev machine itself), but
// breaks completely from the Android emulator: there, "localhost" refers to
// the EMULATOR'S OWN loopback, not the host PC, so the redirect target is
// unreachable (and the self-signed dev cert isn't trusted there either).
// That's exactly why trip planning (and anything else hitting the backend)
// failed only on Android, never on Chrome. The Flutter app always talks to
// the plain-HTTP port 5220 anyway (see ApiService.baseUrl), so this redirect
// was never actually wanted here.

app.MapControllers();

var summaries = new[]
{
    "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
};

app.MapGet("/weatherforecast", () =>
{
    var forecast = Enumerable.Range(1, 5).Select(index =>
        new WeatherForecast
        (
            DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
            Random.Shared.Next(-20, 55),
            summaries[Random.Shared.Next(summaries.Length)]
        ))
        .ToArray();
    return forecast;
})
.WithName("GetWeatherForecast")
.WithOpenApi();

app.Run();

record WeatherForecast(DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}