# FoodieSpot – Food Review & Restaurant Management

FoodieSpot là ứng dụng web/đa nền tảng để khám phá, đánh giá, lưu quán ăn và đặt bàn. Dự án gồm Flutter frontend, ASP.NET Core Web API backend và SQL Server LocalDB. Giao diện theo phong cách Modern Minimalist với tông trắng, đen và đỏ cam san hô.

## Chức năng chính

### Khách hàng

- Khám phá, tìm kiếm, lọc theo thể loại và chọn ngẫu nhiên quán ăn.
- Xem chi tiết quán: thực đơn, bộ ảnh không gian, bản đồ OpenStreetMap, trạng thái mở/đóng, đánh giá và số lượt lưu.
- Lưu quán vào bookmarks, tạo **một** đánh giá cho mỗi quán và đính kèm tối đa 5 ảnh.
- Đặt bàn; mỗi tài khoản chỉ có một yêu cầu đặt bàn đang hiệu lực và có thể tự hủy.
- Chat trực tiếp với chủ quán.

### Tài khoản doanh nghiệp

- Đăng ký, hoàn thiện hồ sơ doanh nghiệp và tạo hồ sơ quán theo quy trình onboarding.
- Đăng thực đơn, ảnh bìa và tối đa 5 ảnh không gian; gửi hồ sơ để admin duyệt.
- Quản lý quán đã được duyệt: chỉnh sửa thông tin, bật/tắt trạng thái mở cửa, xem bản đồ, thống kê rating/bookmark, đánh giá, tin nhắn và yêu cầu đặt bàn.
- Xác nhận hoặc xử lý yêu cầu đặt bàn; chủ quán không thể tự đánh giá quán của mình.

### Quản trị viên

- Dashboard tổng quan về nhà hàng, trạng thái mở/đóng, người dùng, bookmark, review và rating.
- Duyệt hồ sơ quán doanh nghiệp, quản lý nhà hàng, thể loại, người dùng và đánh giá.
- Xem/xử lý báo cáo đánh giá; quản lý tài khoản User, Business và Admin.

## Kiến trúc thư mục

```text
App Review Food/
├── backend/
│   └── FoodReviewApi/          # ASP.NET Core 10 REST API + Entity Framework Core
├── frontend/
│   └── food_review_app/        # Flutter web/mobile/desktop application
└── README.md
```

## Yêu cầu môi trường

Máy phát triển Windows nên có các thành phần sau:

- [.NET SDK 10](https://dotnet.microsoft.com/download) (backend đặt `TargetFramework` là `net10.0`).
- SQL Server LocalDB, thường được cài cùng Visual Studio hoặc SQL Server Express.
- Flutter SDK có Dart `^3.11.5` hoặc mới hơn tương thích.
- Chrome nếu chạy bản web; Android Emulator/Windows desktop là tùy chọn.

Kiểm tra nhanh sau khi cài:

```powershell
dotnet --version
flutter --version
```

## Cài đặt và chạy dự án

Mở hai cửa sổ terminal tại thư mục gốc `App Review Food`.

### 1. Khởi động backend

```powershell
cd backend\FoodReviewApi
dotnet restore
dotnet run --launch-profile http
```

API mặc định chạy tại `http://localhost:5099`. Khi chạy ở môi trường Development, Swagger có tại:

```text
http://localhost:5099/swagger
```

Lần khởi động đầu tiên backend tự tạo database `FoodReviewDb`, tạo/cập nhật bảng và nạp dữ liệu mẫu. Không cần chạy migration thủ công cho cấu hình mặc định.

### 2. Khởi động Flutter frontend

```powershell
cd frontend\food_review_app
flutter pub get
flutter run -d chrome
```

Có thể thay `chrome` bằng một thiết bị Flutter khác đã được `flutter devices` nhận diện.

Frontend web dùng `http://localhost:5099/api`. Với Android emulator, ứng dụng tự dùng `http://10.0.2.2:5099/api`. Nếu đổi host/port API, cập nhật `baseUrl` trong `frontend\food_review_app\lib\services\api_service.dart`.

## Cấu hình database và bảo mật

Chuỗi kết nối mặc định nằm trong `backend\FoodReviewApi\appsettings.json`:

```json
"DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=FoodReviewDb;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=True"
```

Để dùng SQL Server khác, thay `DefaultConnection` bằng chuỗi kết nối của môi trường bạn trước khi chạy backend.

Khóa ký phiên đang có giá trị phục vụ phát triển local. Khi triển khai, bắt buộc tạo khóa ngẫu nhiên riêng và cung cấp qua biến môi trường, ví dụ:

```powershell
$env:Auth__SessionSigningKey = "mot-khoa-ngau-nhien-dai-va-bao-mat"
dotnet run --launch-profile http
```

Không đưa khóa sản xuất, mật khẩu database hoặc file cấu hình chứa secret lên Git. Backend băm mật khẩu mới bằng PBKDF2; dữ liệu mật khẩu cũ sẽ được nâng cấp khi người dùng đăng nhập thành công.

## Dữ liệu mẫu ban đầu

Khi database chưa có người dùng/thể loại, hệ thống seed các tài khoản sau:

| Vai trò | Tên đăng nhập | Mật khẩu | Mục đích |
|---|---|---|---|
| Admin | `admin` | `admin123` | Kiểm tra dashboard, quản lý và duyệt quán |
| User | `user` | `user123` | Kiểm tra trải nghiệm khách hàng |

> Đây là tài khoản demo cho môi trường local. Hãy đổi hoặc xóa trước khi demo công khai/triển khai thực tế.

Các thể loại mẫu: `All`, `Vietnamese`, `Japanese`, `Italian`, `Bakery & Cafe`, `Korean`, `Fine Dining`.

Bốn quán mẫu đã được duyệt cùng tọa độ Hà Nội:

| Quán | Thể loại | Khu vực |
|---|---|---|
| Phở Thìn Bờ Hồ | Vietnamese | Hoàn Kiếm |
| Nomiya Omakase Sushi | Japanese | Ba Đình |
| La Trattoria del Chef | Italian | Tây Hồ |
| Maison de Pâtisserie | Bakery & Cafe | Hai Bà Trưng |

### Các nhóm dữ liệu được lưu

| Nhóm | Dữ liệu tiêu biểu |
|---|---|
| Người dùng | username, mật khẩu băm, tên hiển thị, vai trò, avatar, thông tin doanh nghiệp, thời điểm tạo/đăng nhập |
| Nhà hàng | tên, mô tả, địa chỉ, category/cuisine, khoảng giá, tọa độ, ảnh bìa, trạng thái duyệt, chủ sở hữu, mở/đóng |
| Nội dung quán | danh sách món ăn, bộ ảnh không gian, lượt bookmark |
| Đánh giá | người gửi, số sao, bình luận, món gợi ý, tối đa 5 ảnh, báo cáo review |
| Đặt bàn & chat | lịch đặt bàn, trạng thái xử lý, hội thoại giữa khách và chủ quán |

Ảnh mới được backend lưu thành file URL dưới `backend\FoodReviewApi\wwwroot\uploads`; ảnh Base64 cũ được tự chuyển đổi khi backend khởi động. Thư mục uploads cần được giữ lại và sao lưu khi triển khai.

## Quy trình nghiệp vụ quan trọng

1. Người dùng Business đăng ký → hoàn thiện hồ sơ và tạo quán → thêm thực đơn/ảnh → gửi admin duyệt.
2. Admin duyệt quán → chủ quán truy cập trang quản lý quán ăn.
3. Khách đặt bàn → chủ quán nhận thông báo/chat → chủ quán xác nhận hoặc xử lý yêu cầu.
4. Một khách chỉ đánh giá một lần cho cùng một quán; chủ quán không thể đánh giá quán do mình sở hữu.
5. Quán đóng cửa không được ưu tiên trong danh sách/ngẫu nhiên và có hiển thị trạng thái riêng.

## Kiểm tra chất lượng

```powershell
# Backend
cd backend\FoodReviewApi
dotnet build

# Flutter
cd frontend\food_review_app
flutter analyze
```

## Khắc phục sự cố thường gặp

### `API Unreachable` hoặc timeout

- Bảo đảm backend đang chạy trước frontend và lắng nghe ở `http://localhost:5099`.
- Mở `http://localhost:5099/swagger` để xác minh API hoạt động.
- Nếu vừa sửa backend, dừng rồi chạy lại `dotnet run`; Flutter hot reload không tự nạp code C# mới.

### Không kết nối được SQL Server LocalDB

- Cài SQL Server Express LocalDB hoặc đổi `DefaultConnection` sang SQL Server đang có sẵn.
- Kiểm tra quyền Windows của tài khoản hiện tại đối với LocalDB.

### Muốn tạo lại toàn bộ dữ liệu demo

Xóa database **`FoodReviewDb`** bằng SQL Server Object Explorer/SQL Server Management Studio, rồi khởi động lại backend. Thao tác này xóa vĩnh viễn toàn bộ dữ liệu local hiện tại; initializer sẽ tạo lại schema và dữ liệu mẫu.

### Ảnh không hiển thị

- Kiểm tra URL backend và thư mục `wwwroot\uploads` còn tồn tại.
- Với deployment, cấu hình reverse proxy phục vụ static files và sử dụng URL public/HTTPS phù hợp.

## Thư viện nổi bật

**Flutter:** `http`, `flutter_map`, `latlong2`, `google_fonts`, `image_picker`, `file_picker`, `go_router`, `responsive_framework`, `shadcn_ui`, `shared_preferences`.

**Backend:** ASP.NET Core 10, Entity Framework Core SQL Server, Swagger/Swashbuckle và CORS cho môi trường phát triển.

## Ghi chú triển khai

- Chuyển chuỗi kết nối, khóa phiên và URL API sang biến môi trường/secret manager.
- Bật HTTPS, giới hạn CORS theo domain frontend thật và sao lưu SQL Server cùng thư mục uploads.
- Đổi/xóa tài khoản seed trước khi public hệ thống.
