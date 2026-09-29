using FoodReviewApi.Models;
using Microsoft.EntityFrameworkCore;

namespace FoodReviewApi.Data;

public static class DbInitializer
{
    public static async Task SeedAsync(FoodReviewDbContext context)
    {
        await context.Database.EnsureCreatedAsync();

        // Ensure Latitude and Longitude columns exist in case SQL Server DB was created with older schema
        try
        {
            await context.Database.ExecuteSqlRawAsync(@"
                IF OBJECT_ID('ChatConversations', 'U') IS NULL
                BEGIN
                    CREATE TABLE ChatConversations (Id INT IDENTITY PRIMARY KEY, RestaurantId INT NOT NULL, CustomerId INT NOT NULL, OwnerId INT NOT NULL, UpdatedAt DATETIME2 NOT NULL);
                    CREATE UNIQUE INDEX IX_ChatConversations_Participants ON ChatConversations(RestaurantId, CustomerId, OwnerId);
                END
                IF OBJECT_ID('ChatMessages', 'U') IS NULL
                BEGIN
                    CREATE TABLE ChatMessages (Id INT IDENTITY PRIMARY KEY, ConversationId INT NOT NULL, SenderId INT NOT NULL, Text NVARCHAR(2000) NOT NULL, CreatedAt DATETIME2 NOT NULL, IsRead BIT NOT NULL);
                    CREATE INDEX IX_ChatMessages_ConversationId_Id ON ChatMessages(ConversationId, Id);
                END
                IF OBJECT_ID('ChatMessages', 'U') IS NOT NULL
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'ChatMessages' AND COLUMN_NAME = 'CustomerText')
                        ALTER TABLE ChatMessages ADD CustomerText NVARCHAR(2000) NOT NULL DEFAULT '';
                    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'ChatMessages' AND COLUMN_NAME = 'OwnerText')
                        ALTER TABLE ChatMessages ADD OwnerText NVARCHAR(2000) NOT NULL DEFAULT '';
                END
                IF OBJECT_ID('Reservations', 'U') IS NOT NULL
                   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Reservations_UserId_Status_ReservationTime')
                    CREATE INDEX IX_Reservations_UserId_Status_ReservationTime ON Reservations(UserId, Status, ReservationTime);
                IF OBJECT_ID('ReviewReports', 'U') IS NULL
                BEGIN
                    CREATE TABLE [ReviewReports] (
                        [Id] INT IDENTITY PRIMARY KEY,
                        [ReviewId] INT NOT NULL,
                        [RestaurantId] INT NOT NULL,
                        [ReporterId] INT NOT NULL,
                        [Reason] NVARCHAR(MAX) NOT NULL,
                        [Status] NVARCHAR(32) NOT NULL DEFAULT 'Pending',
                        [CreatedAt] DATETIME2 NOT NULL,
                        [ResolvedBy] INT NULL,
                        [ResolvedAt] DATETIME2 NULL
                    );
                    CREATE UNIQUE INDEX IX_ReviewReports_Pending ON [ReviewReports] ([ReviewId], [ReporterId]) WHERE [Status] = 'Pending';
                END
                IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Restaurants')
                BEGIN
                    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Restaurants' AND COLUMN_NAME = 'Latitude')
                    BEGIN
                        ALTER TABLE [Restaurants] ADD [Latitude] FLOAT NOT NULL DEFAULT 21.0285;
                    END
                    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Restaurants' AND COLUMN_NAME = 'Longitude')
                    BEGIN
                        ALTER TABLE [Restaurants] ADD [Longitude] FLOAT NOT NULL DEFAULT 105.8542;
                    END
                    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Restaurants' AND COLUMN_NAME = 'CategoryId')
                    BEGIN
                        ALTER TABLE [Restaurants] ADD [CategoryId] INT NULL;
                    END
                    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Restaurants' AND COLUMN_NAME = 'ApprovalStatus')
                        ALTER TABLE [Restaurants] ADD [ApprovalStatus] NVARCHAR(MAX) NOT NULL DEFAULT 'Approved';
                    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Restaurants' AND COLUMN_NAME = 'SubmittedAt')
                        ALTER TABLE [Restaurants] ADD [SubmittedAt] DATETIME2 NULL;
                    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Restaurants' AND COLUMN_NAME = 'OwnerId')
                        ALTER TABLE [Restaurants] ADD [OwnerId] INT NULL;
                    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Restaurants' AND COLUMN_NAME = 'IsOpen')
                        ALTER TABLE [Restaurants] ADD [IsOpen] BIT NOT NULL DEFAULT 1;
                END

                IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Reservations')
                BEGIN
                    CREATE TABLE [Reservations] (
                        [Id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                        [RestaurantId] INT NOT NULL,
                        [UserId] INT NOT NULL,
                        [CustomerName] NVARCHAR(MAX) NOT NULL,
                        [Phone] NVARCHAR(MAX) NOT NULL,
                        [ReservationTime] DATETIME2 NOT NULL,
                        [PartySize] INT NOT NULL,
                        [Note] NVARCHAR(MAX) NOT NULL DEFAULT '',
                        [Status] NVARCHAR(MAX) NOT NULL DEFAULT 'Pending',
                        [CreatedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
                        [LastLoginAt] DATETIME2 NULL
                    );
                END

                IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Users')
                BEGIN
                    CREATE TABLE [Users] (
                        [Id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                        [Username] NVARCHAR(MAX) NOT NULL,
                        [Password] NVARCHAR(MAX) NOT NULL,
                        [FullName] NVARCHAR(MAX) NOT NULL,
                        [Role] NVARCHAR(MAX) NOT NULL DEFAULT 'User',
                        [AvatarUrl] NVARCHAR(MAX) NULL,
                        [CreatedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE()
                    );
                END

                IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Users')
                BEGIN
                    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'BusinessName')
                        ALTER TABLE [Users] ADD [BusinessName] NVARCHAR(MAX) NULL;
                    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'BusinessAddress')
                        ALTER TABLE [Users] ADD [BusinessAddress] NVARCHAR(MAX) NULL;
                    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'Email')
                        ALTER TABLE [Users] ADD [Email] NVARCHAR(MAX) NULL;
                    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'BusinessType')
                        ALTER TABLE [Users] ADD [BusinessType] NVARCHAR(MAX) NULL;
                    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Users' AND COLUMN_NAME = 'LastLoginAt')
                        ALTER TABLE [Users] ADD [LastLoginAt] DATETIME2 NULL;
                END

                IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Bookmarks')
                BEGIN
                    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Bookmarks' AND COLUMN_NAME = 'UserId')
                    BEGIN
                        ALTER TABLE [Bookmarks] ADD [UserId] INT NOT NULL DEFAULT 1;
                    END
                END

                -- Ensure Foreign Key: Bookmarks -> Users (ON DELETE CASCADE)
                IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Bookmarks')
                   AND EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Users')
                   AND NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_Bookmarks_Users_UserId')
                BEGIN
                    DELETE FROM [Bookmarks] WHERE [UserId] NOT IN (SELECT [Id] FROM [Users]);
                    ALTER TABLE [Bookmarks] WITH CHECK ADD CONSTRAINT [FK_Bookmarks_Users_UserId] 
                    FOREIGN KEY ([UserId]) REFERENCES [Users]([Id]) ON DELETE CASCADE;
                END

                -- Ensure Foreign Key: Bookmarks -> Restaurants (ON DELETE CASCADE)
                IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Bookmarks')
                   AND EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Restaurants')
                   AND NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_Bookmarks_Restaurants_RestaurantId')
                BEGIN
                    DELETE FROM [Bookmarks] WHERE [RestaurantId] NOT IN (SELECT [Id] FROM [Restaurants]);
                    ALTER TABLE [Bookmarks] WITH CHECK ADD CONSTRAINT [FK_Bookmarks_Restaurants_RestaurantId] 
                    FOREIGN KEY ([RestaurantId]) REFERENCES [Restaurants]([Id]) ON DELETE CASCADE;
                END

                -- Ensure Foreign Key: Restaurants -> Categories (ON DELETE SET NULL)
                IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Restaurants')
                   AND EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Categories')
                   AND NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_Restaurants_Categories_CategoryId')
                BEGIN
                    UPDATE [Restaurants] SET [CategoryId] = NULL WHERE [CategoryId] IS NOT NULL AND [CategoryId] NOT IN (SELECT [Id] FROM [Categories]);
                    ALTER TABLE [Restaurants] WITH CHECK ADD CONSTRAINT [FK_Restaurants_Categories_CategoryId] 
                    FOREIGN KEY ([CategoryId]) REFERENCES [Categories]([Id]) ON DELETE SET NULL;
                END

                -- Add UserId column to Reviews if not exists
                IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Reviews')
                BEGIN
                    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Reviews' AND COLUMN_NAME = 'UserId')
                    BEGIN
                        ALTER TABLE [Reviews] ADD [UserId] INT NULL;
                    END
                END

                -- Ensure Foreign Key: Reviews -> Users (ON DELETE SET NULL)
                IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Reviews')
                   AND EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Users')
                   AND NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_Reviews_Users_UserId')
                BEGIN
                    ALTER TABLE [Reviews] WITH CHECK ADD CONSTRAINT [FK_Reviews_Users_UserId]
                    FOREIGN KEY ([UserId]) REFERENCES [Users]([Id]) ON DELETE SET NULL;
                END

                IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'RestaurantImages')
                BEGIN
                    CREATE TABLE [RestaurantImages] (
                        [Id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                        [RestaurantId] INT NOT NULL,
                        [ImageUrl] NVARCHAR(MAX) NOT NULL,
                        [CreatedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
                        CONSTRAINT [FK_RestaurantImages_Restaurants_RestaurantId]
                            FOREIGN KEY ([RestaurantId]) REFERENCES [Restaurants]([Id]) ON DELETE CASCADE
                    );
                END

                IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ReviewImages')
                BEGIN
                    CREATE TABLE [ReviewImages] (
                        [Id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                        [ReviewId] INT NOT NULL,
                        [ImageUrl] NVARCHAR(MAX) NOT NULL,
                        [CreatedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
                        CONSTRAINT [FK_ReviewImages_Reviews_ReviewId]
                            FOREIGN KEY ([ReviewId]) REFERENCES [Reviews]([Id]) ON DELETE CASCADE
                    );
                END

                IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'MenuItems')
                BEGIN
                    CREATE TABLE [MenuItems] (
                        [Id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                        [RestaurantId] INT NOT NULL,
                        [Name] NVARCHAR(MAX) NOT NULL,
                        [Description] NVARCHAR(MAX) NOT NULL DEFAULT '',
                        [Price] DECIMAL(18,2) NOT NULL,
                        [ImageUrl] NVARCHAR(MAX) NOT NULL DEFAULT '',
                        [IsAvailable] BIT NOT NULL DEFAULT 1,
                        [DisplayOrder] INT NOT NULL DEFAULT 0,
                        CONSTRAINT [FK_MenuItems_Restaurants_RestaurantId]
                            FOREIGN KEY ([RestaurantId]) REFERENCES [Restaurants]([Id]) ON DELETE CASCADE
                    );
                END
            ");
        }
        catch
        {
            // Ignore raw SQL execution errors if table is not created yet
        }

        // Seed default users if empty
        if (!await context.Users.AnyAsync())
        {
            var defaultUsers = new List<User>
            {
                new User
                {
                    Username = "admin",
                    Password = PasswordSecurity.Hash("admin123"),
                    FullName = "Quản Trị Viên",
                    Role = "Admin",
                    AvatarUrl = "https://i.pravatar.cc/150?img=68",
                    CreatedAt = DateTime.UtcNow
                },
                new User
                {
                    Username = "user",
                    Password = PasswordSecurity.Hash("user123"),
                    FullName = "Minh Anh Foodie",
                    Role = "User",
                    AvatarUrl = "https://i.pravatar.cc/150?img=32",
                    CreatedAt = DateTime.UtcNow
                }
            };
            await context.Users.AddRangeAsync(defaultUsers);
            await context.SaveChangesAsync();
        }

        if (await context.Categories.AnyAsync())
        {
            // Auto-link existing restaurants with categories if CategoryId is null
            var unlinked = await context.Restaurants.Where(r => r.CategoryId == null).ToListAsync();
            if (unlinked.Any())
            {
                var existingCats = await context.Categories.ToListAsync();
                foreach (var r in unlinked)
                {
                    var matched = existingCats.FirstOrDefault(c => c.Name.Equals(r.Cuisine, StringComparison.OrdinalIgnoreCase));
                    if (matched != null)
                    {
                        r.CategoryId = matched.Id;
                    }
                }
                await context.SaveChangesAsync();
            }
            return; // DB already seeded
        }

        var categories = new List<Category>
        {
            new Category { Name = "All", Icon = "grid" },
            new Category { Name = "Vietnamese", Icon = "soup" },
            new Category { Name = "Japanese", Icon = "fish" },
            new Category { Name = "Italian", Icon = "pizza" },
            new Category { Name = "Bakery & Cafe", Icon = "coffee" },
            new Category { Name = "Korean", Icon = "flame" },
            new Category { Name = "Fine Dining", Icon = "wine" }
        };

        await context.Categories.AddRangeAsync(categories);
        await context.SaveChangesAsync();

        var catViet = categories.First(c => c.Name == "Vietnamese").Id;
        var catJap = categories.First(c => c.Name == "Japanese").Id;
        var catItalian = categories.First(c => c.Name == "Italian").Id;
        var catBakery = categories.First(c => c.Name == "Bakery & Cafe").Id;

        var restaurants = new List<Restaurant>
        {
            new Restaurant
            {
                Name = "Phở Thìn Bờ Hồ",
                Description = "Hương vị phở bò truyền thống lâu đời Hà Nội với nước dùng trong vắt, đậm đà thanh ngọt.",
                Address = "61 Đinh Tiên Hoàng, Hoàn Kiếm, Hà Nội",
                CategoryId = catViet,
                Cuisine = "Vietnamese",
                PriceRange = "50.000đ - 200.000đ",
                CoverImageUrl = "https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&w=1000&q=80",
                Rating = 4.8,
                ReviewCount = 142,
                Latitude = 21.028511,
                Longitude = 105.854198,
                Reviews = new List<Review>
                {
                    new Review
                    {
                        UserName = "Minh Anh",
                        UserAvatarUrl = "https://i.pravatar.cc/150?img=32",
                        Rating = 5.0,
                        Comment = "Nước dùng phở cực kỳ thanh ngọt tự nhiên, thịt bò mềm vừa tới. Không gian tối giản nhưng ấm cúng.",
                        RecommendedDish = "Phở Bò Tái Nạm",
                        ImageUrl = "https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&w=600&q=80",
                        CreatedAt = DateTime.UtcNow.AddDays(-2)
                    },
                    new Review
                    {
                        UserName = "Hoàng Nam",
                        UserAvatarUrl = "https://i.pravatar.cc/150?img=11",
                        Rating = 4.5,
                        Comment = "Phở rất ngon, quẩy giòn rụm. Phục vụ nhanh nhẹn dù quán lúc nào cũng đông khách.",
                        RecommendedDish = "Phở Tái Lăn",
                        ImageUrl = "",
                        CreatedAt = DateTime.UtcNow.AddDays(-5)
                    }
                }
            },
            new Restaurant
            {
                Name = "Nomiya Omakase Sushi",
                Description = "Trải nghiệm Omakase phong cách Minimalism tinh tế với nguồn hải sản nhập khẩu trực tiếp từ thị trường Toyosu Tokyo.",
                Address = "15 Lê Thánh Tôn, Quận 1, TP. Hồ Chí Minh",
                CategoryId = catJap,
                Cuisine = "Japanese",
                PriceRange = "> 500.000đ",
                CoverImageUrl = "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=1000&q=80",
                Rating = 4.9,
                ReviewCount = 98,
                Latitude = 10.776918,
                Longitude = 106.700862,
                Reviews = new List<Review>
                {
                    new Review
                    {
                        UserName = "Trần Khánh Băng",
                        UserAvatarUrl = "https://i.pravatar.cc/150?img=47",
                        Rating = 5.0,
                        Comment = "Mỗi miếng Nigiri là một tác phẩm nghệ thuật. Đầu bếp giải thích cặn kẽ nguồn gốc từng loại cá.",
                        RecommendedDish = "Otoro Uni Caviar Nigiri",
                        ImageUrl = "https://images.unsplash.com/photo-1611143669185-af224c5e3252?auto=format&fit=crop&w=600&q=80",
                        CreatedAt = DateTime.UtcNow.AddDays(-1)
                    }
                }
            },
            new Restaurant
            {
                Name = "La Trattoria del Chef",
                Description = "Món Ý chuẩn vị phong cách nhà làm với mỳ Pasta tươi tự làm hằng ngày và pizza nướng củi độc đáo.",
                Address = "42 Xuân Diệu, Tây Hồ, Hà Nội",
                CategoryId = catItalian,
                Cuisine = "Italian",
                PriceRange = "200.000đ - 500.000đ",
                CoverImageUrl = "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=1000&q=80",
                Rating = 4.7,
                ReviewCount = 76,
                Latitude = 21.066421,
                Longitude = 105.827798,
                Reviews = new List<Review>
                {
                    new Review
                    {
                        UserName = "David Miller",
                        UserAvatarUrl = "https://i.pravatar.cc/150?img=60",
                        Rating = 4.5,
                        Comment = "Authentic Italian carbonara without cream! Highly recommended for pasta lovers.",
                        RecommendedDish = "Truffle Spaghetti Carbonara",
                        ImageUrl = "https://images.unsplash.com/photo-1621996346565-e3d5d6281288?auto=format&fit=crop&w=600&q=80",
                        CreatedAt = DateTime.UtcNow.AddDays(-4)
                    }
                }
            },
            new Restaurant
            {
                Name = "Maison de Pâtisserie",
                Description = "Tiệm bánh ngọt Pháp phong cách kiến trúc tối giản trắng & đen thanh lịch, không gian yên tĩnh phù hợp làm việc và trò chuyện.",
                Address = "88 Nguyễn Du, Quận 1, TP. Hồ Chí Minh",
                CategoryId = catBakery,
                Cuisine = "Bakery & Cafe",
                PriceRange = "50.000đ - 200.000đ",
                CoverImageUrl = "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=1000&q=80",
                Rating = 4.6,
                ReviewCount = 115,
                Latitude = 10.778104,
                Longitude = 106.699211,
                Reviews = new List<Review>
                {
                    new Review
                    {
                        UserName = "Linh Chi",
                        UserAvatarUrl = "https://i.pravatar.cc/150?img=26",
                        Rating = 5.0,
                        Comment = "Bánh Croissant vỏ giòn xốp thơm ngậy vị bơ AOP, Matcha Latte thơm vị trà đậm đà.",
                        RecommendedDish = "Almond Butter Croissant & Cold Brew",
                        ImageUrl = "https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&w=600&q=80",
                        CreatedAt = DateTime.UtcNow.AddDays(-3)
                    }
                }
            }
        };

        foreach (var restaurant in restaurants)
        {
            restaurant.ApprovalStatus = "Approved";
        }
        await context.Restaurants.AddRangeAsync(restaurants);
        await context.SaveChangesAsync();
    }
}
