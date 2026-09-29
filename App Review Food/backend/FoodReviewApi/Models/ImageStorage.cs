using System.Security.Cryptography;
using FoodReviewApi.Data;
using Microsoft.EntityFrameworkCore;

namespace FoodReviewApi.Models;

public static class ImageStorage
{
    private const int MaxImageBytes = 5 * 1024 * 1024;

    public static string PersistDataUrl(string url, string webRootPath)
    {
        if (!url.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase)) return url;

        var comma = url.IndexOf(',');
        if (comma < 0) throw new InvalidOperationException("Định dạng ảnh không hợp lệ.");
        var mime = url[5..comma].Split(';')[0].ToLowerInvariant();
        var extension = mime switch
        {
            "image/jpeg" => ".jpg",
            "image/png" => ".png",
            "image/webp" => ".webp",
            "image/gif" => ".gif",
            _ => throw new InvalidOperationException("Định dạng ảnh không được hỗ trợ.")
        };
        var bytes = Convert.FromBase64String(url[(comma + 1)..]);
        if (bytes.Length == 0 || bytes.Length > MaxImageBytes)
            throw new InvalidOperationException("Ảnh phải nhỏ hơn 5MB.");

        var directory = Path.Combine(webRootPath, "uploads");
        Directory.CreateDirectory(directory);
        var fileName = $"{Convert.ToHexString(RandomNumberGenerator.GetBytes(16))}{extension}";
        File.WriteAllBytes(Path.Combine(directory, fileName), bytes);
        return $"/uploads/{fileName}";
    }

    public static async Task MigrateDataUrlsAsync(FoodReviewDbContext db, string webRootPath)
    {
        var restaurants = await db.Restaurants.Include(item => item.Images).ToListAsync();
        var reviews = await db.Reviews.Include(item => item.Images).ToListAsync();
        var menuItems = await db.MenuItems.ToListAsync();
        var changed = false;

        foreach (var restaurant in restaurants)
        {
            if (restaurant.CoverImageUrl.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase))
            {
                restaurant.CoverImageUrl = PersistDataUrl(restaurant.CoverImageUrl, webRootPath);
                changed = true;
            }
            foreach (var image in restaurant.Images.Where(image => image.ImageUrl.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase)))
            {
                image.ImageUrl = PersistDataUrl(image.ImageUrl, webRootPath);
                changed = true;
            }
        }

        foreach (var review in reviews)
        {
            if (review.ImageUrl.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase))
            {
                review.ImageUrl = PersistDataUrl(review.ImageUrl, webRootPath);
                changed = true;
            }
            foreach (var image in review.Images.Where(image => image.ImageUrl.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase)))
            {
                image.ImageUrl = PersistDataUrl(image.ImageUrl, webRootPath);
                changed = true;
            }
        }

        foreach (var item in menuItems.Where(item => item.ImageUrl.StartsWith("data:image/", StringComparison.OrdinalIgnoreCase)))
        {
            item.ImageUrl = PersistDataUrl(item.ImageUrl, webRootPath);
            changed = true;
        }

        if (changed) await db.SaveChangesAsync();
    }
}
