using Microsoft.EntityFrameworkCore;
using FoodReviewApi.Models;

namespace FoodReviewApi.Data;

public class FoodReviewDbContext : DbContext
{
    public FoodReviewDbContext(DbContextOptions<FoodReviewDbContext> options) : base(options)
    {
    }

    public DbSet<Restaurant> Restaurants => Set<Restaurant>();
    public DbSet<Review> Reviews => Set<Review>();
    public DbSet<ReviewReport> ReviewReports => Set<ReviewReport>();
    public DbSet<ChatConversation> ChatConversations => Set<ChatConversation>();
    public DbSet<ChatMessage> ChatMessages => Set<ChatMessage>();
    public DbSet<Category> Categories => Set<Category>();
    public DbSet<Bookmark> Bookmarks => Set<Bookmark>();
    public DbSet<User> Users => Set<User>();
    public DbSet<RestaurantImage> RestaurantImages => Set<RestaurantImage>();
    public DbSet<ReviewImage> ReviewImages => Set<ReviewImage>();
    public DbSet<MenuItem> MenuItems => Set<MenuItem>();
    public DbSet<Reservation> Reservations => Set<Reservation>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.Entity<ChatConversation>().HasIndex(c => new { c.RestaurantId, c.CustomerId, c.OwnerId }).IsUnique();
        modelBuilder.Entity<ChatMessage>().HasIndex(m => new { m.ConversationId, m.Id });
        modelBuilder.Entity<ChatMessage>().Property(m => m.Text).HasMaxLength(2000);
        modelBuilder.Entity<ChatMessage>().Property(m => m.CustomerText).HasMaxLength(2000);
        modelBuilder.Entity<ChatMessage>().Property(m => m.OwnerText).HasMaxLength(2000);
        modelBuilder.Entity<ChatConversation>()
            .HasMany(c => c.Messages)
            .WithOne(m => m.Conversation)
            .HasForeignKey(m => m.ConversationId)
            .OnDelete(DeleteBehavior.Cascade);
        modelBuilder.Entity<Reservation>().HasIndex(r => new { r.UserId, r.Status, r.ReservationTime });
        modelBuilder.Entity<ReviewReport>()
            .HasIndex(r => new { r.ReviewId, r.ReporterId })
            .HasDatabaseName("IX_ReviewReports_Pending")
            .IsUnique()
            .HasFilter("[Status] = 'Pending'");

        // Restaurant - Reviews (1 - N, Cascade)
        modelBuilder.Entity<Restaurant>()
            .HasMany(r => r.Reviews)
            .WithOne()
            .HasForeignKey(r => r.RestaurantId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<Restaurant>()
            .HasMany(r => r.Images)
            .WithOne()
            .HasForeignKey(i => i.RestaurantId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<Review>()
            .HasMany(r => r.Images)
            .WithOne()
            .HasForeignKey(i => i.ReviewId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<Restaurant>()
            .HasMany(r => r.MenuItems)
            .WithOne()
            .HasForeignKey(item => item.RestaurantId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<Reservation>()
            .HasOne<Restaurant>()
            .WithMany()
            .HasForeignKey(reservation => reservation.RestaurantId)
            .OnDelete(DeleteBehavior.Cascade);

        // Restaurant - Category (N - 1, SetNull on Category delete)
        modelBuilder.Entity<Restaurant>()
            .HasOne(r => r.Category)
            .WithMany(c => c.Restaurants)
            .HasForeignKey(r => r.CategoryId)
            .OnDelete(DeleteBehavior.SetNull);

        // Bookmark - User (N - 1, Cascade on User delete)
        modelBuilder.Entity<Bookmark>()
            .HasOne(b => b.User)
            .WithMany(u => u.Bookmarks)
            .HasForeignKey(b => b.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        // Bookmark - Restaurant (N - 1, Cascade on Restaurant delete)
        modelBuilder.Entity<Bookmark>()
            .HasOne(b => b.Restaurant)
            .WithMany()
            .HasForeignKey(b => b.RestaurantId)
            .OnDelete(DeleteBehavior.Cascade);

        // Review - User (N - 1, SetNull on User delete)
        modelBuilder.Entity<Review>()
            .HasOne(r => r.User)
            .WithMany()
            .HasForeignKey(r => r.UserId)
            .OnDelete(DeleteBehavior.SetNull);
    }
}
