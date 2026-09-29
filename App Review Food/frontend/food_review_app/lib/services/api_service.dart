import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurant.dart';
import '../models/review.dart';
import '../models/category.dart';
import '../models/user.dart';

class ApiService {
  // Base URLs for localhost (desktop/web) & Android Emulator
  static const String baseUrlWeb = 'http://localhost:5099/api';
  static const String baseUrlMobile = 'http://10.0.2.2:5099/api';

  // ✅ Đã sửa: Trả về baseUrlMobile khi không phải Web
  static String get baseUrl => kIsWeb ? baseUrlWeb : baseUrlMobile;

  // Header helper với Authorization Token
  static Map<String, String> _getHeaders({bool hasBody = true}) {
    final headers = <String, String>{};
    if (hasBody) {
      headers['Content-Type'] = 'application/json';
    }
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  // ✅ Đã sửa: Sử dụng Uri để xử lý URL an toàn hơn cắt chuỗi thủ công
  static String resolveImageUrl(String url) {
    if (!url.startsWith('/')) return url;
    final baseUri = Uri.parse(baseUrl);
    final origin = '${baseUri.scheme}://${baseUri.host}:${baseUri.port}';
    return '$origin$url';
  }

  // Auth Session State
  static UserModel? currentUser;
  static String? authToken;
  static const _sessionTokenKey = 'food_review.session_token';
  static const _sessionUserKey = 'food_review.session_user';

  static bool get isLoggedIn => currentUser != null;

  static Future<void> _persistSession() async {
    if (authToken == null || currentUser == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionTokenKey, authToken!);
    await preferences.setString(_sessionUserKey, jsonEncode(currentUser!.toJson()));
  }

  static Future<bool> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final savedToken = preferences.getString(_sessionTokenKey);
    final savedUser = preferences.getString(_sessionUserKey);
    if (savedToken == null || savedUser == null) return false;

    try {
      authToken = savedToken;
      currentUser = UserModel.fromJson(jsonDecode(savedUser) as Map<String, dynamic>);
      final response = await http
          .get(Uri.parse('$baseUrl/auth/session'), headers: _getHeaders(hasBody: false))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        await logout();
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      currentUser = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      await _persistSession();
      await loadUserBookmarks();
      return true;
    } catch (e) {
      debugPrint('restoreSession error: $e');
      await logout();
      return false;
    }
  }
  static Future<dynamic> chatRequest(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl/chat$path');
    final response =
        await (body == null
                ? http.get(uri, headers: _getHeaders(hasBody: false))
                : http.post(
                    uri,
                    headers: _getHeaders(),
                    body: jsonEncode(body),
                  ))
            .timeout(const Duration(seconds: 12));
    if (response.statusCode == 401) {
      throw Exception('Vui lòng đăng nhập lại để chat.');
    }
    if (response.statusCode == 403) {
      throw Exception('Bạn không có quyền xem cuộc trò chuyện này.');
    }
    if (response.statusCode != 200) {
      String message = 'Không thể tải hoặc gửi tin nhắn. Vui lòng thử lại.';
      try {
        message = jsonDecode(response.body)['message'] ?? message;
      } catch (_) {}
      throw Exception(message);
    }
    return jsonDecode(response.body);
  }

  static bool get isAdmin => currentUser?.isAdmin ?? false;

  static Future<dynamic> reviewReportRequest(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl/review-reports$path');
    final response =
        await (body == null
                ? http.get(uri, headers: _getHeaders(hasBody: false))
                : http.post(
                    uri,
                    headers: _getHeaders(),
                    body: jsonEncode(body),
                  ))
            .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      if (response.statusCode == 401) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }
      if (response.statusCode == 403) {
        throw Exception('Bạn không có quyền thực hiện thao tác này.');
      }
      String message = 'Không thể xử lý báo cáo. Vui lòng thử lại.';
      try {
        message = jsonDecode(response.body)['message'] ?? message;
      } catch (_) {}
      throw Exception(message);
    }
    return jsonDecode(response.body);
  }

  static Future<List<Map<String, dynamic>>> getRestaurantReservations(
    int restaurantId,
  ) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/reservations/restaurant/$restaurantId'),
          headers: _getHeaders(hasBody: false),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Không thể tải danh sách đặt bàn.');
    }
    return (jsonDecode(response.body) as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<void> updateReservationStatus(
    int reservationId, {
    required bool confirm,
  }) async {
    final response = await http
        .post(
          Uri.parse(
            '$baseUrl/reservations/$reservationId/${confirm ? 'confirm' : 'reject'}',
          ),
          headers: _getHeaders(),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 401) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }
    if (response.statusCode == 403) {
      throw Exception('Bạn không có quyền xử lý yêu cầu này.');
    }
    if (response.statusCode == 409) {
      throw Exception('Yêu cầu này đã được xử lý. Hãy tải lại danh sách.');
    }
    if (response.statusCode != 200) {
      String message = 'Không thể cập nhật trạng thái đặt bàn.';
      try {
        message = jsonDecode(response.body)['message'] ?? message;
      } catch (_) {}
      throw Exception(message);
    }
  }

  static Future<List<Map<String, dynamic>>> getMyReservations() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/reservations/mine'),
          headers: _getHeaders(hasBody: false),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 401) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }
    if (response.statusCode != 200) {
      throw Exception('Không thể tải danh sách đặt bàn.');
    }
    return (jsonDecode(response.body) as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<void> cancelMyReservation(int reservationId) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/reservations/$reservationId/cancel'),
          headers: _getHeaders(),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 401) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }
    if (response.statusCode == 403) {
      throw Exception('Bạn không có quyền hủy bàn này.');
    }
    if (response.statusCode == 409) {
      throw Exception('Bàn này không thể hủy hoặc đã được cập nhật.');
    }
    if (response.statusCode != 200) {
      throw Exception('Không thể hủy đặt bàn. Vui lòng thử lại.');
    }
  }

  static Future<void> deleteOldRestaurantReservation(int reservationId) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/reservations/$reservationId'),
          headers: _getHeaders(hasBody: false),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 401) {
      throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
    }
    if (response.statusCode == 403) {
      throw Exception('Bạn không có quyền xóa yêu cầu này.');
    }
    if (response.statusCode == 409) {
      throw Exception('Không thể xóa bàn đang chờ hoặc đã xác nhận.');
    }
    if (response.statusCode != 204) {
      throw Exception('Không thể xóa thông báo đặt bàn.');
    }
  }

  static Future<Map<String, dynamic>> createReservation({
    required int restaurantId,
    required String customerName,
    required String phone,
    required DateTime reservationTime,
    required int partySize,
    String note = '',
  }) async {
    if (!isLoggedIn) {
      return {'success': false, 'message': 'Vui lòng đăng nhập để đặt bàn.'};
    }
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/reservations'),
            headers: _getHeaders(),
            body: jsonEncode({
              'restaurantId': restaurantId,
              'userId': currentUser!.id,
              'customerName': customerName,
              'phone': phone,
              'reservationTime': reservationTime.toUtc().toIso8601String(),
              'partySize': partySize,
              'note': note,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final data = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      return response.statusCode == 201
          ? {'success': true}
          : {
              'success': false,
              'message': data['message'] ?? 'Không thể đặt bàn.',
            };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối. Vui lòng thử lại.'};
    }
  }

  // POST Login
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: _getHeaders(),
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        authToken = data['token'];
        currentUser = UserModel.fromJson(data['user']);
        await _persistSession();
        await loadUserBookmarks();
        return {'success': true, 'message': 'Đăng nhập thành công!'};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Đăng nhập thất bại!',
        };
      }
    } catch (e) {
      debugPrint('login error: $e');
      return {'success': false, 'message': 'Không thể kết nối máy chủ. Vui lòng thử lại.'};
    }
  }

  // POST Register
  static Future<Map<String, dynamic>> register(
    String username,
    String password,
    String fullName, {
    String role = 'User',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: _getHeaders(),
            body: jsonEncode({
              'username': username,
              'password': password,
              'fullName': fullName,
              'role': role,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        authToken = data['token'];
        currentUser = UserModel.fromJson(data['user']);
        await _persistSession();
        await loadUserBookmarks();
        return {
          'success': true,
          'message': data['message'] ?? 'Đăng ký thành công!',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Đăng ký thất bại!',
        };
      }
    } catch (e) {
      debugPrint('register error: $e');
      return {'success': false, 'message': 'Không thể kết nối máy chủ. Vui lòng thử lại.'};
    }
  }

  static Future<bool> updateBusinessProfile({
    required String businessName,
    required String businessAddress,
    required String email,
    required String businessType,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/auth/business-profile'),
            headers: _getHeaders(),
            body: jsonEncode({
              'businessName': businessName,
              'businessAddress': businessAddress,
              'email': email,
              'businessType': businessType,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['user'] is Map<String, dynamic>) {
        currentUser = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      }
      return true;
    } catch (e) {
      debugPrint('updateBusinessProfile error: $e');
      return false;
    }
  }

  // Logout
  static Future<void> logout() async {
    currentUser = null;
    authToken = null;
    _bookmarkedIds.clear();
    _categoriesCache = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionTokenKey);
    await preferences.remove(_sessionUserKey);
  }

  // Mock Users storage
  static final List<UserModel> _mockUsers = [
    UserModel(
      id: 1,
      username: 'admin',
      fullName: 'Quản Trị Viên',
      role: 'Admin',
      avatarUrl: 'https://i.pravatar.cc/150?img=68',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    UserModel(
      id: 2,
      username: 'user',
      fullName: 'Minh Anh Foodie',
      role: 'User',
      avatarUrl: 'https://i.pravatar.cc/150?img=32',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
  ];

  // GET Users (Admin)
  static Future<List<UserModel>> getUsers() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/auth/users'),
            headers: _getHeaders(hasBody: false),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('API Unreachable, using fallback mock users: $e');
    }

    return List.from(_mockUsers);
  }

  // POST Create User (Admin)
  static Future<Map<String, dynamic>> createUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
    String? avatarUrl,
  }) async {
    final payload = {
      'username': username,
      'password': password,
      'fullName': fullName,
      'role': role,
      'avatarUrl': avatarUrl ?? '',
    };

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/users'),
            headers: _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Thêm người dùng thành công!',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Thêm người dùng thất bại!',
        };
      }
    } catch (e) {
      debugPrint('createUser error: $e');
      return {'success': false, 'message': 'Không thể kết nối máy chủ. Vui lòng thử lại.'};
    }
  }

  // PUT Update User (Admin)
  static Future<Map<String, dynamic>> updateUser(
    int id, {
    required String fullName,
    required String role,
    String? password,
    String? avatarUrl,
  }) async {
    final payload = <String, dynamic>{'fullName': fullName, 'role': role};
    if (password != null && password.isNotEmpty) {
      payload['password'] = password;
    }
    if (avatarUrl != null) {
      payload['avatarUrl'] = avatarUrl;
    }

    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/auth/users/$id'),
            headers: _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Cập nhật thành công!',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Cập nhật thất bại!',
        };
      }
    } catch (e) {
      debugPrint('updateUser error: $e');
      return {'success': false, 'message': 'Không thể kết nối máy chủ. Vui lòng thử lại.'};
    }
  }

  // DELETE User (Admin)
  static Future<Map<String, dynamic>> deleteUser(int id) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/auth/users/$id'),
            headers: _getHeaders(hasBody: false),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Xóa người dùng thành công!',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể xóa người dùng này!',
        };
      }
    } catch (e) {
      debugPrint('deleteUser error: $e');
      return {'success': false, 'message': 'Không thể kết nối máy chủ. Vui lòng thử lại.'};
    }
  }

  // Local Bookmarks cache
  static final Set<int> _bookmarkedIds = {};

  static bool isBookmarked(int restaurantId) =>
      _bookmarkedIds.contains(restaurantId);

  // Fallback Mock Categories
  static final List<CategoryModel> _mockCategories = [
    CategoryModel(id: 1, name: 'All', icon: 'grid'),
    CategoryModel(id: 2, name: 'Vietnamese', icon: 'soup'),
    CategoryModel(id: 3, name: 'Japanese', icon: 'fish'),
    CategoryModel(id: 4, name: 'Italian', icon: 'pizza'),
    CategoryModel(id: 5, name: 'Bakery & Cafe', icon: 'coffee'),
    CategoryModel(id: 6, name: 'Fine Dining', icon: 'wine'),
  ];

  static List<CategoryModel>? _categoriesCache;
  static Future<List<CategoryModel>>? _categoriesInFlight;

  // GET Categories
  static Future<List<CategoryModel>> getCategories() {
    final cached = _categoriesCache;
    if (cached != null) return Future.value(List.unmodifiable(cached));

    return _categoriesInFlight ??= _fetchCategories().whenComplete(() {
      _categoriesInFlight = null;
    });
  }

  static Future<List<CategoryModel>> _fetchCategories() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/categories'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final list = data
            .map((json) => CategoryModel.fromJson(json))
            .toList(growable: false);
        if (list.isNotEmpty) {
          _categoriesCache = list;
          return List.unmodifiable(list);
        }
      }
    } catch (e) {
      debugPrint('API Unreachable, using fallback categories: $e');
    }

    return List.unmodifiable(_mockCategories);
  }

  // GET Restaurants with filter & search
  static Future<List<RestaurantModel>> getRestaurants({
    String? category,
    String? search,
    bool includeUnapproved = false,
    int? ownerId,
    bool businessOnly = false,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (category != null && category.isNotEmpty && category != 'All') {
        queryParams['category'] = category;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (includeUnapproved) {
        queryParams['includeUnapproved'] = 'true';
      }
      if (ownerId != null) queryParams['ownerId'] = ownerId.toString();
      if (businessOnly) queryParams['businessOnly'] = 'true';

      final uri = Uri.parse(
        '$baseUrl/restaurants',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await http
          .get(uri, headers: _getHeaders(hasBody: false))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((json) => RestaurantModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('API Unreachable, using fallback mock restaurants: $e');
    }

    return _mockRestaurants.where((r) {
      bool matchesCategory =
          category == null ||
          category.isEmpty ||
          category == 'All' ||
          r.cuisine.toLowerCase() == category.toLowerCase();
      bool matchesSearch =
          search == null ||
          search.isEmpty ||
          r.name.toLowerCase().contains(search.toLowerCase()) ||
          r.description.toLowerCase().contains(search.toLowerCase()) ||
          r.cuisine.toLowerCase().contains(search.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  // GET Restaurant Detail
  static Future<RestaurantModel?> getRestaurantDetail(int id) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/restaurants/$id'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return RestaurantModel.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('API Unreachable, using fallback detail: $e');
    }

    try {
      return _mockRestaurants.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  // POST Create Review
  static Future<Map<String, dynamic>> addReview({
    required int restaurantId,
    required double rating,
    required String comment,
    required String recommendedDish,
    String imageUrl = '',
    List<String> imageUrls = const [],
  }) async {
    if (!isLoggedIn) {
      return {
        'success': false,
        'needLogin': true,
        'message': 'Vui lòng đăng nhập để viết đánh giá!',
      };
    }

    final payload = {
      'restaurantId': restaurantId,
      'userId': currentUser!.id,
      'rating': rating,
      'comment': comment,
      'recommendedDish': recommendedDish,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
    };

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/reviews'),
            headers: _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'needLogin': true,
          'message': 'Vui lòng đăng nhập để viết đánh giá!',
        };
      }
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Không thể gửi đánh giá!',
      };
    } catch (e) {
      debugPrint('Không thể xác nhận kết quả gửi đánh giá: $e');
      return {
        'success': false,
        'message':
            'Không thể xác nhận đánh giá đã được lưu. Hãy tải lại trang trước khi thử lại.',
      };
    }
  }

  // PUT Update Review
  static Future<Map<String, dynamic>> updateReview({
    required int reviewId,
    required double rating,
    required String comment,
    required String recommendedDish,
    String imageUrl = '',
    List<String> imageUrls = const [],
  }) async {
    if (!isLoggedIn) {
      return {
        'success': false,
        'needLogin': true,
        'message': 'Vui lòng đăng nhập!',
      };
    }

    final payload = {
      'rating': rating,
      'comment': comment,
      'recommendedDish': recommendedDish,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
    };

    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/reviews/$reviewId?userId=${currentUser!.id}'),
            headers: _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {'success': true};
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return {
          'success': false,
          'message': 'Bạn không có quyền chỉnh sửa đánh giá này!',
        };
      }
      final data = jsonDecode(response.body);
      return {
        'success': false,
        'message': data['message'] ?? 'Không thể cập nhật!',
      };
    } catch (e) {
      debugPrint('updateReview error: $e');
      return {'success': false, 'message': 'Lỗi kết nối!'};
    }
  }

  // DELETE Review
  static Future<Map<String, dynamic>> deleteReview(int reviewId) async {
    if (!isLoggedIn) {
      return {
        'success': false,
        'needLogin': true,
        'message': 'Vui lòng đăng nhập!',
      };
    }

    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/reviews/$reviewId?userId=${currentUser!.id}'),
            headers: _getHeaders(hasBody: false),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {'success': true};
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return {
          'success': false,
          'message': 'Bạn không có quyền xóa đánh giá này!',
        };
      }
      final data = jsonDecode(response.body);
      return {'success': false, 'message': data['message'] ?? 'Không thể xóa!'};
    } catch (e) {
      debugPrint('deleteReview error: $e');
      return {'success': false, 'message': 'Lỗi kết nối!'};
    }
  }

  // POST Upload review image
  static Future<String?> uploadReviewImage(
    List<int> imageBytes,
    String fileName,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/reviews/upload'),
      );
      if (authToken != null) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }
      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: fileName),
      );
      final streamed = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] as String?;
      }
      debugPrint('Image upload failed: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('uploadReviewImage error: $e');
      return null;
    }
  }

  // Load Bookmarks
  static Future<void> loadUserBookmarks() async {
    _bookmarkedIds.clear();
    if (!isLoggedIn) return;

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/bookmarks/ids?userId=${currentUser!.id}'),
            headers: _getHeaders(hasBody: false),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        _bookmarkedIds.addAll(data.map((e) => (e as num).toInt()));
      }
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
    }
  }

  // Toggle Bookmark
  static Future<bool> toggleBookmark(int restaurantId) async {
    if (!isLoggedIn) return false;

    final userId = currentUser!.id;
    final wasBookmarked = _bookmarkedIds.contains(restaurantId);

    // Optimistic UI Update
    if (wasBookmarked) {
      _bookmarkedIds.remove(restaurantId);
    } else {
      _bookmarkedIds.add(restaurantId);
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/bookmarks/toggle/$restaurantId?userId=$userId'),
            headers: _getHeaders(hasBody: false),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool isBookmarkedOnServer =
            data['isBookmarked'] ?? !wasBookmarked;
        if (isBookmarkedOnServer) {
          _bookmarkedIds.add(restaurantId);
        } else {
          _bookmarkedIds.remove(restaurantId);
        }
      } else {
        // Rollback nếu thất bại
        if (wasBookmarked) {
          _bookmarkedIds.add(restaurantId);
        } else {
          _bookmarkedIds.remove(restaurantId);
        }
      }
    } catch (e) {
      debugPrint('toggleBookmark error: $e');
      if (wasBookmarked) {
        _bookmarkedIds.add(restaurantId);
      } else {
        _bookmarkedIds.remove(restaurantId);
      }
    }

    return _bookmarkedIds.contains(restaurantId);
  }

  // GET Bookmarked Restaurants
  static Future<List<RestaurantModel>> getBookmarks() async {
    if (!isLoggedIn) return [];

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/bookmarks?userId=${currentUser!.id}'),
            headers: _getHeaders(hasBody: false),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final list = data
            .map((json) => RestaurantModel.fromJson(json))
            .toList();
        _bookmarkedIds.clear();
        _bookmarkedIds.addAll(list.map((r) => r.id));
        return list;
      }
    } catch (e) {
      debugPrint('Fallback get bookmarks: $e');
    }

    final all = await getRestaurants();
    return all.where((r) => _bookmarkedIds.contains(r.id)).toList();
  }

  // Admin API Methods
  static Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/admin/stats'),
            headers: _getHeaders(hasBody: false),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('API Unreachable, returning mock admin stats: $e');
    }

    final totalReviews = _mockRestaurants.fold<int>(
      0,
      (sum, r) => sum + r.reviews.length,
    );
    final avgRating = _mockRestaurants.isEmpty
        ? 0.0
        : (_mockRestaurants.fold<double>(0.0, (sum, r) => sum + r.rating) /
              _mockRestaurants.length);
    final latestReview =
        _mockRestaurants
            .expand(
              (restaurant) => restaurant.reviews.map(
                (review) => {
                  'review': review,
                  'restaurantName': restaurant.name,
                },
              ),
            )
            .toList()
          ..sort(
            (a, b) => (b['review'] as ReviewModel).createdAt.compareTo(
              (a['review'] as ReviewModel).createdAt,
            ),
          );
    final mostRecent = latestReview.isEmpty ? null : latestReview.first;
    final review = mostRecent?['review'] as ReviewModel?;

    return {
      'totalRestaurants': _mockRestaurants.length,
      'openRestaurants': _mockRestaurants
          .where((restaurant) => restaurant.isOpen)
          .length,
      'closedRestaurants': _mockRestaurants
          .where((restaurant) => !restaurant.isOpen)
          .length,
      'totalReviews': totalReviews,
      'averageSystemRating': double.parse(avgRating.toStringAsFixed(1)),
      'totalBookmarks': _bookmarkedIds.length,
      'totalCategories': _mockCategories.length,
      'totalUsers': _mockUsers.length,
      'onlineUsers': currentUser == null ? 0 : 1,
      'recentReviews': [],
      'latestReview': review == null
          ? null
          : {
              'id': review.id,
              'restaurantId': review.restaurantId,
              'restaurantName': mostRecent!['restaurantName'],
              'userName': review.userName,
              'comment': review.comment,
              'rating': review.rating,
              'createdAt': review.createdAt.toIso8601String(),
            },
    };
  }

  static Future<bool> createRestaurant(RestaurantModel rest) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/restaurants'),
            headers: _getHeaders(),
            body: jsonEncode(rest.toJson()),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 201 || response.statusCode == 200) return true;
    } catch (e) {
      debugPrint('createRestaurant error: $e');
    }
    return false;
  }

  static Future<RestaurantModel?> createBusinessRestaurant(
    RestaurantModel rest,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/restaurants'),
            headers: _getHeaders(),
            body: jsonEncode(rest.toJson()),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 201 || response.statusCode == 200) {
        return RestaurantModel.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('createBusinessRestaurant error: $e');
    }
    return null;
  }

  static Future<bool> submitRestaurantProfile(int restaurantId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/restaurants/$restaurantId/submit'),
            headers: _getHeaders(hasBody: false),
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('submitRestaurantProfile error: $e');
      return false;
    }
  }

  static Future<bool> reviewRestaurantProfile(
    int restaurantId, {
    required bool approved,
  }) async {
    try {
      final action = approved ? 'approve' : 'reject';
      final response = await http
          .post(
            Uri.parse('$baseUrl/restaurants/$restaurantId/$action'),
            headers: _getHeaders(hasBody: false),
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('reviewRestaurantProfile error: $e');
      return false;
    }
  }

  static Future<bool> updateRestaurant(RestaurantModel rest) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/restaurants/${rest.id}'),
            headers: _getHeaders(),
            body: jsonEncode(rest.toJson()),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) return true;
    } catch (e) {
      debugPrint('updateRestaurant error: $e');
    }
    return false;
  }

  static Future<bool> deleteRestaurant(int id) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/restaurants/$id'),
            headers: _getHeaders(hasBody: false),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) return true;
    } catch (e) {
      debugPrint('deleteRestaurant error: $e');
    }
    return false;
  }

  static Future<List<ReviewModel>> getAllReviews() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/reviews'),
            headers: _getHeaders(hasBody: false),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((j) => ReviewModel.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('Fallback get all reviews: $e');
    }

    final List<ReviewModel> allReviews = [];
    for (var r in _mockRestaurants) {
      allReviews.addAll(r.reviews);
    }
    return allReviews;
  }

  static Future<bool> createCategory(String name, String icon) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/categories'),
            headers: _getHeaders(),
            body: jsonEncode({'name': name, 'icon': icon}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 201 || response.statusCode == 200) {
        _categoriesCache = null;
        return true;
      }
    } catch (e) {
      debugPrint('createCategory error: $e');
    }
    return false;
  }

  static Future<Map<String, dynamic>> deleteCategory(int id) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/categories/$id'),
            headers: _getHeaders(hasBody: false),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _categoriesCache = null;
        return {
          'success': true,
          'message': data['message'] ?? 'Đã xóa thể loại thành công',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể xóa thể loại!',
        };
      }
    } catch (e) {
      debugPrint('deleteCategory error: $e');
      return {'success': false, 'message': 'Không thể kết nối máy chủ. Vui lòng thử lại.'};
    }
  }

  // Fallback Mock Data
  static final List<RestaurantModel> _mockRestaurants = [
    RestaurantModel(
      id: 1,
      name: "Phở Thìn Bờ Hồ",
      description:
          "Hương vị phở bò truyền thống lâu đời Hà Nội với nước dùng trong vắt, đậm đà thanh ngọt.",
      address: "61 Đinh Tiên Hoàng, Hoàn Kiếm, Hà Nội",
      cuisine: "Vietnamese",
      priceRange: '50.000đ - 200.000đ',
      coverImageUrl:
          "https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&w=1000&q=80",
      rating: 4.8,
      reviewCount: 142,
      latitude: 21.028511,
      longitude: 105.854198,
      reviews: [
        ReviewModel(
          id: 101,
          restaurantId: 1,
          userName: "Minh Anh",
          userAvatarUrl: "https://i.pravatar.cc/150?img=32",
          rating: 5.0,
          comment:
              "Nước dùng phở cực kỳ thanh ngọt tự nhiên, thịt bò mềm vừa tới. Không gian tối giản nhưng ấm cúng.",
          recommendedDish: "Phở Bò Tái Nạm",
          imageUrl:
              "https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&w=600&q=80",
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ],
    ),
    RestaurantModel(
      id: 2,
      name: "Nomiya Omakase Sushi",
      description:
          "Trải nghiệm Omakase phong cách Minimalism tinh tế với nguồn hải sản nhập khẩu trực tiếp từ Nhật Bản.",
      address: "15 Lê Thánh Tôn, Quận 1, TP. Hồ Chí Minh",
      cuisine: "Japanese",
      priceRange: '> 500.000đ',
      coverImageUrl:
          "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=1000&q=80",
      rating: 4.9,
      reviewCount: 98,
      latitude: 10.776918,
      longitude: 106.700862,
      reviews: [
        ReviewModel(
          id: 102,
          restaurantId: 2,
          userName: "Trần Khánh Băng",
          userAvatarUrl: "https://i.pravatar.cc/150?img=47",
          rating: 5.0,
          comment:
              "Mỗi miếng Nigiri là một tác phẩm nghệ thuật. Đầu bếp giải thích cặn kẽ nguồn gốc từng loại cá.",
          recommendedDish: "Otoro Uni Caviar Nigiri",
          imageUrl:
              "https://images.unsplash.com/photo-1611143669185-af224c5e3252?auto=format&fit=crop&w=600&q=80",
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
    ),
    RestaurantModel(
      id: 3,
      name: "Maison de Pâtisserie",
      description:
          "Tiệm bánh ngọt Pháp phong cách kiến trúc tối giản trắng & đen thanh lịch, không gian yên tĩnh.",
      address: "88 Nguyễn Du, Quận 1, TP. Hồ Chí Minh",
      cuisine: "Bakery & Cafe",
      priceRange: '50.000đ - 200.000đ',
      coverImageUrl:
          "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=1000&q=80",
      rating: 4.6,
      reviewCount: 115,
      latitude: 10.778104,
      longitude: 106.699211,
      reviews: [
        ReviewModel(
          id: 103,
          restaurantId: 3,
          userName: "Linh Chi",
          userAvatarUrl: "https://i.pravatar.cc/150?img=26",
          rating: 5.0,
          comment:
              "Bánh Croissant vỏ giòn xốp thơm ngậy vị bơ AOP, Matcha Latte thơm vị trà đậm đà.",
          recommendedDish: "Almond Butter Croissant & Cold Brew",
          imageUrl:
              "https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&w=600&q=80",
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ],
    ),
  ];
}
