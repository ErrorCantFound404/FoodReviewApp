class UserModel {
  final int id;
  final String username;
  final String fullName;
  final String role;
  final String avatarUrl;
  final String businessName;
  final String businessAddress;
  final String email;
  final String businessType;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final int bookmarkCount;
  final int reviewCount;
  final List<String> businessRestaurants;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.avatarUrl,
    this.businessName = '',
    this.businessAddress = '',
    this.email = '',
    this.businessType = '',
    required this.createdAt,
    this.lastLoginAt,
    this.bookmarkCount = 0,
    this.reviewCount = 0,
    this.businessRestaurants = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      fullName: json['fullName'] ?? '',
      role: json['role'] ?? 'User',
      avatarUrl: json['avatarUrl'] ?? '',
      businessName: json['businessName'] ?? '',
      businessAddress: json['businessAddress'] ?? '',
      email: json['email'] ?? '',
      businessType: json['businessType'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lastLoginAt: json['lastLoginAt'] == null
          ? null
          : DateTime.tryParse(json['lastLoginAt'].toString()),
      bookmarkCount: json['bookmarkCount'] ?? 0,
      reviewCount: json['reviewCount'] ?? 0,
      businessRestaurants: (json['businessRestaurants'] as List? ?? const [])
          .map((restaurant) => restaurant.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'fullName': fullName,
      'role': role,
      'avatarUrl': avatarUrl,
      'businessName': businessName,
      'businessAddress': businessAddress,
      'email': email,
      'businessType': businessType,
      'createdAt': createdAt.toIso8601String(),
      if (lastLoginAt != null) 'lastLoginAt': lastLoginAt!.toIso8601String(),
      'bookmarkCount': bookmarkCount,
      'reviewCount': reviewCount,
      'businessRestaurants': businessRestaurants,
    };
  }

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isBusiness => role.toLowerCase() == 'business';
}
