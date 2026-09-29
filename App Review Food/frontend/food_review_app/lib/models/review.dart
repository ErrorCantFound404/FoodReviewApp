class ReviewModel {
  final int id;
  final int restaurantId;
  final int? userId;
  final String userName;
  final String userAvatarUrl;
  final double rating;
  final String comment;
  final String recommendedDish;
  final String imageUrl;
  final List<String> imageUrls;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.restaurantId,
    this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.rating,
    required this.comment,
    required this.recommendedDish,
    required this.imageUrl,
    this.imageUrls = const [],
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] ?? 0,
      restaurantId: json['restaurantId'] ?? 0,
      userId: json['userId'],
      userName: json['userName'] ?? 'Anonymous',
      userAvatarUrl: json['userAvatarUrl'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      comment: json['comment'] ?? '',
      recommendedDish: json['recommendedDish'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      imageUrls: _imageUrlsFromJson(json['images'], json['imageUrl'] ?? ''),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      if (userId != null) 'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'rating': rating,
      'comment': comment,
      'recommendedDish': recommendedDish,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static List<String> _imageUrlsFromJson(dynamic images, String imageUrl) {
    final urls = <String>[];
    if (images is List) {
      for (final image in images) {
        final url = image is Map ? image['imageUrl']?.toString() : image?.toString();
        if (url != null && url.isNotEmpty) urls.add(url);
      }
    }
    if (urls.isEmpty && imageUrl.isNotEmpty) urls.add(imageUrl);
    return urls;
  }
}
