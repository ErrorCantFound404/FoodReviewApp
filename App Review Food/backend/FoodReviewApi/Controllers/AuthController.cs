using FoodReviewApi.Data;
using FoodReviewApi.DTOs;
using FoodReviewApi.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Cryptography;

namespace FoodReviewApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly FoodReviewDbContext _context;

    public AuthController(FoodReviewDbContext context)
    {
        _context = context;
    }

    private async Task<User?> CurrentAdmin()
    {
        var userId = ApiSessions.Resolve(Request.Headers.Authorization.ToString());
        if (userId == null) return null;

        var user = await _context.Users.FindAsync(userId.Value);
        return user?.Role.Equals("Admin", StringComparison.OrdinalIgnoreCase) == true
            ? user
            : null;
    }

    private bool HasAuthenticatedSession() =>
        ApiSessions.Resolve(Request.Headers.Authorization.ToString()) != null;

    // POST: api/auth/login
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Username) || string.IsNullOrWhiteSpace(dto.Password))
        {
            return BadRequest(new { message = "Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu!" });
        }

        var user = await _context.Users.FirstOrDefaultAsync(u => u.Username.ToLower() == dto.Username.ToLower());
        if (user == null)
        {
            return BadRequest(new { message = "Tên đăng nhập hoặc mật khẩu không chính xác!" });
        }

        var isLegacyPassword = !PasswordSecurity.IsHashed(user.Password);
        var passwordMatches = isLegacyPassword
            ? CryptographicOperations.FixedTimeEquals(
                System.Text.Encoding.UTF8.GetBytes(user.Password),
                System.Text.Encoding.UTF8.GetBytes(dto.Password))
            : PasswordSecurity.Verify(dto.Password, user.Password);
        if (!passwordMatches)
            return BadRequest(new { message = "Tên đăng nhập hoặc mật khẩu không chính xác!" });

        if (isLegacyPassword)
            user.Password = PasswordSecurity.Hash(dto.Password);

        user.LastLoginAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return Ok(new
        {
            token = ApiSessions.Issue(user.Id),
            user = new
            {
                user.Id,
                user.Username,
                user.FullName,
                user.Role,
                user.AvatarUrl,
                user.BusinessName,
                user.BusinessAddress,
                user.Email,
                user.BusinessType,
                user.CreatedAt,
                user.LastLoginAt
            }
        });
    }

    // GET: api/auth/session
    [HttpGet("session")]
    public async Task<IActionResult> GetSession()
    {
        var userId = ApiSessions.Resolve(Request.Headers.Authorization.ToString());
        if (userId == null) return Unauthorized(new { message = "Phiên đăng nhập đã hết hạn." });

        var user = await _context.Users.FindAsync(userId.Value);
        if (user == null) return Unauthorized(new { message = "Tài khoản không còn tồn tại." });

        return Ok(new { user = new
        {
            user.Id, user.Username, user.FullName, user.Role, user.AvatarUrl,
            user.BusinessName, user.BusinessAddress, user.Email, user.BusinessType,
            user.CreatedAt, user.LastLoginAt
        }});
    }

    // POST: api/auth/register
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.Username) || string.IsNullOrWhiteSpace(dto.Password) || string.IsNullOrWhiteSpace(dto.FullName))
        {
            return BadRequest(new { message = "Vui lòng điền đầy đủ các thông tin đăng ký!" });
        }

        var exists = await _context.Users.AnyAsync(u => u.Username.ToLower() == dto.Username.ToLower());
        if (exists)
        {
            return BadRequest(new { message = "Tên đăng nhập này đã được sử dụng!" });
        }

        var role = dto.Role.Equals("Business", StringComparison.OrdinalIgnoreCase) ? "Business" : "User";
        var newUser = new User
        {
            Username = dto.Username.Trim(),
            Password = PasswordSecurity.Hash(dto.Password),
            FullName = dto.FullName.Trim(),
            Role = role,
            BusinessName = role == "Business" ? dto.BusinessName?.Trim() : null,
            BusinessAddress = role == "Business" ? dto.BusinessAddress?.Trim() : null,
            Email = role == "Business" ? dto.Email?.Trim() : null,
            BusinessType = role == "Business" ? dto.BusinessType?.Trim() : null,
            AvatarUrl = $"https://i.pravatar.cc/150?u={Guid.NewGuid()}",
            CreatedAt = DateTime.UtcNow,
            LastLoginAt = DateTime.UtcNow
        };

        _context.Users.Add(newUser);
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Đăng ký tài khoản thành công!",
            token = ApiSessions.Issue(newUser.Id),
            user = new
            {
                newUser.Id,
                newUser.Username,
                newUser.FullName,
                newUser.Role,
                newUser.AvatarUrl,
                newUser.BusinessName,
                newUser.BusinessAddress,
                newUser.Email,
                newUser.BusinessType,
                newUser.CreatedAt,
                newUser.LastLoginAt
            }
        });
    }

    // PUT: api/auth/business-profile
    [HttpPut("business-profile")]
    public async Task<IActionResult> UpdateBusinessProfile([FromBody] BusinessProfileDto dto)
    {
        var userId = ApiSessions.Resolve(Request.Headers.Authorization.ToString());
        if (userId == null) return Unauthorized(new { message = "Vui lòng đăng nhập lại." });

        var user = await _context.Users.FindAsync(userId.Value);
        if (user == null || !user.Role.Equals("Business", StringComparison.OrdinalIgnoreCase))
        {
            return StatusCode(403, new { message = "Chỉ tài khoản doanh nghiệp mới được cập nhật hồ sơ này." });
        }

        if (string.IsNullOrWhiteSpace(dto.BusinessName) || string.IsNullOrWhiteSpace(dto.BusinessAddress) ||
            string.IsNullOrWhiteSpace(dto.Email) || string.IsNullOrWhiteSpace(dto.BusinessType))
        {
            return BadRequest(new { message = "Vui lòng điền đầy đủ thông tin doanh nghiệp." });
        }

        user.BusinessName = dto.BusinessName.Trim();
        user.BusinessAddress = dto.BusinessAddress.Trim();
        user.Email = dto.Email.Trim();
        user.BusinessType = dto.BusinessType.Trim();
        await _context.SaveChangesAsync();

        return Ok(new { message = "Đã cập nhật hồ sơ doanh nghiệp.", user = new
        {
            user.Id, user.Username, user.FullName, user.Role, user.AvatarUrl,
            user.BusinessName, user.BusinessAddress, user.Email, user.BusinessType,
            user.CreatedAt, user.LastLoginAt
        }});
    }

    // GET: api/auth/users (for Admin)
    [HttpGet("users")]
    public async Task<IActionResult> GetUsers()
    {
        if (await CurrentAdmin() == null)
        {
            return HasAuthenticatedSession()
                ? StatusCode(StatusCodes.Status403Forbidden, new { message = "Bạn không có quyền xem danh sách người dùng." })
                : Unauthorized(new { message = "Vui lòng đăng nhập bằng tài khoản Admin." });
        }

        var users = await _context.Users
            .OrderByDescending(u => u.CreatedAt)
            .Select(u => new
            {
                u.Id,
                u.Username,
                u.FullName,
                u.Role,
                u.AvatarUrl,
                u.BusinessName,
                u.BusinessAddress,
                u.Email,
                u.BusinessType,
                u.CreatedAt,
                u.LastLoginAt,
                BookmarkCount = _context.Bookmarks.Count(bookmark => bookmark.UserId == u.Id),
                ReviewCount = _context.Reviews.Count(review => review.UserId == u.Id),
                BusinessRestaurants = _context.Restaurants
                    .Where(restaurant => restaurant.OwnerId == u.Id)
                    .Select(restaurant => restaurant.Name)
                    .ToList()
            }).ToListAsync();

        return Ok(users);
    }

    // POST: api/auth/users (Create User by Admin)
    [HttpPost("users")]
    public async Task<IActionResult> CreateUser([FromBody] CreateUserDto dto)
    {
        if (await CurrentAdmin() == null)
        {
            return HasAuthenticatedSession()
                ? StatusCode(StatusCodes.Status403Forbidden, new { message = "Bạn không có quyền tạo người dùng." })
                : Unauthorized(new { message = "Vui lòng đăng nhập bằng tài khoản Admin." });
        }

        if (string.IsNullOrWhiteSpace(dto.Username) || string.IsNullOrWhiteSpace(dto.Password) || string.IsNullOrWhiteSpace(dto.FullName))
        {
            return BadRequest(new { message = "Vui lòng nhập đầy đủ Tên đăng nhập, Mật khẩu và Họ tên!" });
        }

        var exists = await _context.Users.AnyAsync(u => u.Username.ToLower() == dto.Username.ToLower());
        if (exists)
        {
            return BadRequest(new { message = "Tên đăng nhập này đã tồn tại trong hệ thống!" });
        }

        var user = new User
        {
            Username = dto.Username.Trim(),
            Password = PasswordSecurity.Hash(dto.Password),
            FullName = dto.FullName.Trim(),
            Role = string.IsNullOrWhiteSpace(dto.Role) ? "User" : dto.Role.Trim(),
            AvatarUrl = string.IsNullOrWhiteSpace(dto.AvatarUrl) ? $"https://i.pravatar.cc/150?u={Guid.NewGuid()}" : dto.AvatarUrl.Trim(),
            CreatedAt = DateTime.UtcNow
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetUsers), new { id = user.Id }, new
        {
            message = "Thêm người dùng mới thành công!",
            user = new
            {
                user.Id,
                user.Username,
                user.FullName,
                user.Role,
                user.AvatarUrl,
                user.CreatedAt
            }
        });
    }

    // PUT: api/auth/users/{id} (Update User by Admin)
    [HttpPut("users/{id}")]
    public async Task<IActionResult> UpdateUser(int id, [FromBody] UpdateUserDto dto)
    {
        if (await CurrentAdmin() == null)
        {
            return HasAuthenticatedSession()
                ? StatusCode(StatusCodes.Status403Forbidden, new { message = "Bạn không có quyền cập nhật người dùng." })
                : Unauthorized(new { message = "Vui lòng đăng nhập bằng tài khoản Admin." });
        }

        var user = await _context.Users.FindAsync(id);
        if (user == null)
        {
            return NotFound(new { message = "Không tìm thấy người dùng này!" });
        }

        if (!string.IsNullOrWhiteSpace(dto.FullName))
        {
            user.FullName = dto.FullName.Trim();
        }

        if (!string.IsNullOrWhiteSpace(dto.Role))
        {
            user.Role = dto.Role.Trim();
        }

        if (!string.IsNullOrWhiteSpace(dto.Password))
        {
            user.Password = PasswordSecurity.Hash(dto.Password);
        }

        if (dto.AvatarUrl != null)
        {
            user.AvatarUrl = dto.AvatarUrl.Trim();
        }

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Cập nhật thông tin người dùng thành công!",
            user = new
            {
                user.Id,
                user.Username,
                user.FullName,
                user.Role,
                user.AvatarUrl,
                user.CreatedAt
            }
        });
    }

    // DELETE: api/auth/users/{id} (Delete User by Admin)
    [HttpDelete("users/{id}")]
    public async Task<IActionResult> DeleteUser(int id)
    {
        if (await CurrentAdmin() == null)
        {
            return HasAuthenticatedSession()
                ? StatusCode(StatusCodes.Status403Forbidden, new { message = "Bạn không có quyền xóa người dùng." })
                : Unauthorized(new { message = "Vui lòng đăng nhập bằng tài khoản Admin." });
        }

        var user = await _context.Users.FindAsync(id);
        if (user == null)
        {
            return NotFound(new { message = "Không tìm thấy người dùng!" });
        }

        // Check if user is an Admin account
        if (user.Role.Equals("Admin", StringComparison.OrdinalIgnoreCase))
        {
            return BadRequest(new { message = "Tài khoản Quản trị viên (Admin) không thể bị xóa!" });
        }

        _context.Users.Remove(user);
        await _context.SaveChangesAsync();

        return Ok(new { message = "Đã xóa người dùng thành công!" });
    }
}
