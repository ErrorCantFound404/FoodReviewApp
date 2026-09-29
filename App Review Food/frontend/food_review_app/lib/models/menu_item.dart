class MenuItemModel {
  final int id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool isAvailable;

  const MenuItemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) => MenuItemModel(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        imageUrl: json['imageUrl'] ?? '',
        isAvailable: json['isAvailable'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (id != 0) 'id': id,
        'name': name,
        'description': description,
        'price': price,
        'imageUrl': imageUrl,
        'isAvailable': isAvailable,
      };
}
