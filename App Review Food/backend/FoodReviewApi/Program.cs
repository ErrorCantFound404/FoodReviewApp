using System.Text.Json.Serialization;
using FoodReviewApi.Data;
using FoodReviewApi.Models;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

ApiSessions.Configure(builder.Configuration["Auth:SessionSigningKey"]
    ?? throw new InvalidOperationException("Thiếu cấu hình Auth:SessionSigningKey."));

// Add services to the container with JSON ReferenceHandler.IgnoreCycles
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.ReferenceHandler = ReferenceHandler.IgnoreCycles;
        options.JsonSerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
    });

// Add SQL Server DbContext
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection") 
    ?? "Server=(localdb)\\mssqllocaldb;Database=FoodReviewDb;Trusted_Connection=True;TrustServerCertificate=True";

builder.Services.AddDbContext<FoodReviewDbContext>(options =>
    options.UseSqlServer(connectionString));

// CORS policy for Flutter web / mobile / desktop
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Ensure uploads directory exists
var uploadsPath = Path.Combine(
    app.Environment.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot"),
    "uploads");
Directory.CreateDirectory(uploadsPath);

// Auto-migration & Seed Data on Startup
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    try
    {
        var dbContext = services.GetRequiredService<FoodReviewDbContext>();
        await DbInitializer.SeedAsync(dbContext);
        await ImageStorage.MigrateDataUrlsAsync(dbContext, app.Environment.WebRootPath ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot"));
    }
    catch (Exception ex)
    {
        var logger = services.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "An error occurred seeding the SQL Server Database.");
    }
}

// Enable CORS early in pipeline
app.UseCors("AllowAll");

// Serve static files from wwwroot (uploaded review images)
app.UseStaticFiles();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseAuthorization();
app.MapControllers();

app.Run();
