import 'review.dart';
import 'menu_item.dart';

class RestaurantModel {
  final int id;
  final String name;
  final String description;
  final String address;
  final int? categoryId;
  final String cuisine;
  final String priceRange;
  final String coverImageUrl;
  final String? cardImageUrl;
  final List<String> imageUrls;
  final double rating;
  final int reviewCount;
  final int bookmarkCount;
  final DateTime createdAt;
  final double latitude;
  final double longitude;
  final List<ReviewModel> reviews;
  final List<MenuItemModel> menuItems;
  final String approvalStatus;
  final DateTime? submittedAt;
  final int? ownerId;
  final bool isOpen;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    this.categoryId,
    required this.cuisine,
    required this.priceRange,
    required this.coverImageUrl,
    this.cardImageUrl,
    this.imageUrls = const [],
    required this.rating,
    required this.reviewCount,
    this.bookmarkCount = 0,
    DateTime? createdAt,
    required this.latitude,
    required this.longitude,
    required this.reviews,
    this.menuItems = const [],
    this.approvalStatus = 'Draft',
    this.submittedAt,
    this.ownerId,
    this.isOpen = true,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    var reviewsList = <ReviewModel>[];
    if (json['reviews'] != null && json['reviews'] is List) {
      reviewsList = (json['reviews'] as List)
          .map((r) => ReviewModel.fromJson(r as Map<String, dynamic>))
          .toList();
    }

    return RestaurantModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      categoryId: json['categoryId'],
      cuisine: json['cuisine'] ?? '',
      priceRange: json['priceRange'] ?? r'$$',
      coverImageUrl: json['coverImageUrl'] ?? '',
      cardImageUrl: json['cardImageUrl'],
      imageUrls: _imageUrlsFromJson(json['images'], json['coverImageUrl'] ?? ''),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: json['reviewCount'] ?? reviewsList.length,
      bookmarkCount: json['bookmarkCount'] ?? 0,
      createdAt: json['createdAt'] == null
          ? DateTime.now()
          : DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 21.0285,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 105.8542,
      reviews: reviewsList,
      menuItems: (json['menuItems'] as List? ?? const [])
          .map((item) => MenuItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      approvalStatus: json['approvalStatus'] ?? 'Draft',
      submittedAt: json['submittedAt'] == null ? null : DateTime.tryParse(json['submittedAt'].toString()),
      ownerId: json['ownerId'],
      isOpen: json['isOpen'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      if (categoryId != null) 'categoryId': categoryId,
      'cuisine': cuisine,
      'priceRange': priceRange,
      'coverImageUrl': coverImageUrl,
      'images': imageUrls.map((url) => {'imageUrl': url}).toList(),
      'rating': rating,
      'reviewCount': reviewCount,
      'createdAt': createdAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'reviews': reviews.map((r) => r.toJson()).toList(),
      'menuItems': menuItems.map((item) => item.toJson()).toList(),
      'approvalStatus': approvalStatus,
      if (submittedAt != null) 'submittedAt': submittedAt!.toIso8601String(),
      if (ownerId != null) 'ownerId': ownerId,
      'isOpen': isOpen,
    };
  }

  static List<String> _imageUrlsFromJson(dynamic images, String coverImageUrl) {
    final urls = <String>[];
    if (images is List) {
      for (final image in images) {
        final url = image is Map ? image['imageUrl']?.toString() : image?.toString();
        if (url != null && url.isNotEmpty) urls.add(url);
      }
    }
    if (urls.isEmpty && coverImageUrl.isNotEmpty) urls.add(coverImageUrl);
    return urls;
  }
}
