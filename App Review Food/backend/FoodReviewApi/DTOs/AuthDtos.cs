namespace FoodReviewApi.DTOs;

public class LoginDto
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class RegisterDto
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string Role { get; set; } = "User";
    public string? BusinessName { get; set; }
    public string? BusinessAddress { get; set; }
    public string? Email { get; set; }
    public string? BusinessType { get; set; }
}

public class CreateUserDto
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string FullName { get; set; } = string.Empty;
    public string Role { get; set; } = "User";
    public string? AvatarUrl { get; set; }
}

public class BusinessProfileDto
{
    public string BusinessName { get; set; } = string.Empty;
    public string BusinessAddress { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string BusinessType { get; set; } = string.Empty;
}

public class UpdateUserDto
{
    public string FullName { get; set; } = string.Empty;
    public string Role { get; set; } = "User";
    public string? Password { get; set; }
    public string? AvatarUrl { get; set; }
}
