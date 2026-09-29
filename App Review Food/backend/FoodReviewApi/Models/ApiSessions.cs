using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;

namespace FoodReviewApi.Models;

public static class ApiSessions
{
    private static byte[]? _signingKey;
    private static readonly ConcurrentDictionary<int, DateTime> LastSeenByUser = new();

    public static void Configure(string signingKey)
    {
        if (string.IsNullOrWhiteSpace(signingKey) || signingKey.Length < 32)
            throw new InvalidOperationException("Auth:SessionSigningKey phải có ít nhất 32 ký tự.");
        _signingKey = Encoding.UTF8.GetBytes(signingKey);
    }

    public static string Issue(int userId)
    {
        var expiresAt = DateTimeOffset.UtcNow.AddDays(7).ToUnixTimeSeconds();
        var payload = $"{userId}:{expiresAt}";
        var signature = Sign(payload);
        LastSeenByUser[userId] = DateTime.UtcNow;
        return $"{Encode(payload)}.{Encode(signature)}";
    }

    public static int? Resolve(string header)
    {
        if (!header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)) return null;
        var tokenParts = header[7..].Split('.');
        if (tokenParts.Length != 2) return null;

        try
        {
            var payload = DecodeToString(tokenParts[0]);
            var suppliedSignature = Decode(tokenParts[1]);
            var expectedSignature = Sign(payload);
            if (!CryptographicOperations.FixedTimeEquals(suppliedSignature, expectedSignature)) return null;

            var values = payload.Split(':');
            if (values.Length != 2 || !int.TryParse(values[0], out var userId) ||
                !long.TryParse(values[1], out var expiresAt) ||
                DateTimeOffset.UtcNow.ToUnixTimeSeconds() >= expiresAt)
            {
                return null;
            }

            LastSeenByUser[userId] = DateTime.UtcNow;
            return userId;
        }
        catch (FormatException)
        {
            return null;
        }
    }

    public static int ActiveUserCount(TimeSpan? window = null)
    {
        var cutoff = DateTime.UtcNow.Subtract(window ?? TimeSpan.FromMinutes(5));
        foreach (var pair in LastSeenByUser.Where(pair => pair.Value < cutoff))
            LastSeenByUser.TryRemove(pair.Key, out _);
        return LastSeenByUser.Count;
    }

    private static byte[] Sign(string payload) => HMACSHA256.HashData(
        _signingKey ?? throw new InvalidOperationException("ApiSessions chưa được cấu hình."),
        Encoding.UTF8.GetBytes(payload));

    private static string Encode(string value) => Encode(Encoding.UTF8.GetBytes(value));

    private static string Encode(byte[] value) => Convert.ToBase64String(value)
        .TrimEnd('=')
        .Replace('+', '-')
        .Replace('/', '_');

    private static byte[] Decode(string value)
    {
        var padded = value.Replace('-', '+').Replace('_', '/');
        padded = padded.PadRight(padded.Length + (4 - padded.Length % 4) % 4, '=');
        return Convert.FromBase64String(padded);
    }

    private static string DecodeToString(string value) => Encoding.UTF8.GetString(Decode(value));
}
