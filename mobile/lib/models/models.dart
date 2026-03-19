class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final double? oldPrice;
  final int quantity;
  final String condition;
  final String? sku;
  final String? warrantyInfo;
  final String? storeName;
  final String? storeId;
  final String? categoryName;
  final double rating;
  final int reviewCount;
  final List<String> images;
  final bool isActive;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.oldPrice,
    this.quantity = 0,
    this.condition = 'new',
    this.sku,
    this.warrantyInfo,
    this.storeName,
    this.storeId,
    this.categoryName,
    this.rating = 0,
    this.reviewCount = 0,
    this.images = const [],
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Product.fromJson(Map<String, dynamic> json) {
    final dynamicImages = json['images'];
    final primaryImage = json['primary_image']?.toString();
    final imageList = <String>[];

    if (dynamicImages is List) {
      for (final entry in dynamicImages) {
        if (entry is String && entry.isNotEmpty) {
          imageList.add(entry);
        } else if (entry is Map<String, dynamic>) {
          final url = entry['url']?.toString();
          if (url != null && url.isNotEmpty) {
            imageList.add(url);
          }
        }
      }
    }

    if (imageList.isEmpty && primaryImage != null && primaryImage.isNotEmpty) {
      imageList.add(primaryImage);
    }

    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      oldPrice: json['old_price'] != null
          ? double.tryParse(json['old_price'].toString())
          : null,
      quantity: json['quantity'] ?? 0,
      condition: json['condition'] ?? 'new',
      sku: json['sku'],
      warrantyInfo: json['warranty_info'] ?? json['warranty'],
      storeName: json['store_name'],
      storeId: json['store_id'],
      categoryName: json['category_name'],
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      reviewCount: json['review_count'] ?? json['total_reviews'] ?? 0,
      images: imageList,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

class Category {
  final String id;
  final String name;
  final String? nameAr;
  final String? icon;
  final int productCount;

  Category(
      {required this.id,
      required this.name,
      this.nameAr,
      this.icon,
      this.productCount = 0});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      nameAr: json['name_ar'],
      icon: json['icon'],
      productCount: json['product_count'] ?? 0,
    );
  }
}

class Store {
  final String id;
  final String? userId;
  final String name;
  final String? slug;
  final String? description;
  final String? logo;
  final String? wilaya;
  final String? city;
  final String? phone;
  final String? ownerFirstName;
  final String? ownerLastName;
  final String? ownerAvatar;
  final double rating;
  final int reviewCount;
  final int productCount;

  Store({
    required this.id,
    this.userId,
    required this.name,
    this.slug,
    this.description,
    this.logo,
    this.wilaya,
    this.city,
    this.phone,
    this.ownerFirstName,
    this.ownerLastName,
    this.ownerAvatar,
    this.rating = 0,
    this.reviewCount = 0,
    this.productCount = 0,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] ?? '',
      userId: json['user_id']?.toString(),
      name: json['name'] ?? '',
      slug: json['slug'],
      description: json['description'],
      logo: json['logo'],
      wilaya: json['wilaya'],
      city: json['city'] ?? json['address'],
      phone: json['phone'],
      ownerFirstName: json['owner_first_name']?.toString(),
      ownerLastName: json['owner_last_name']?.toString(),
      ownerAvatar: json['owner_avatar']?.toString(),
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      reviewCount: json['review_count'] ?? json['total_reviews'] ?? 0,
      productCount: json['product_count'] ?? json['total_products'] ?? 0,
    );
  }
}

class PublicProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String? avatar;
  final String role;
  final String? wilaya;
  final String? storeId;
  final String? storeName;
  final String? storeSlug;
  final String? storeLogo;
  final String? storeDescription;
  final String? storeWilaya;
  final double storeRating;
  final int storeReviewCount;
  final int storeProductCount;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final DateTime? createdAt;

  const PublicProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatar,
    this.role = 'buyer',
    this.wilaya,
    this.storeId,
    this.storeName,
    this.storeSlug,
    this.storeLogo,
    this.storeDescription,
    this.storeWilaya,
    this.storeRating = 0,
    this.storeReviewCount = 0,
    this.storeProductCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get hasStore => storeId != null && storeId!.isNotEmpty;

  PublicProfile copyWith({
    bool? isFollowing,
    int? followersCount,
    int? followingCount,
  }) {
    return PublicProfile(
      id: id,
      firstName: firstName,
      lastName: lastName,
      avatar: avatar,
      role: role,
      wilaya: wilaya,
      storeId: storeId,
      storeName: storeName,
      storeSlug: storeSlug,
      storeLogo: storeLogo,
      storeDescription: storeDescription,
      storeWilaya: storeWilaya,
      storeRating: storeRating,
      storeReviewCount: storeReviewCount,
      storeProductCount: storeProductCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
      createdAt: createdAt,
    );
  }

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['created_at']?.toString();

    return PublicProfile(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      role: json['role']?.toString() ?? 'buyer',
      wilaya: json['wilaya']?.toString(),
      storeId: json['store_id']?.toString(),
      storeName: json['store_name']?.toString(),
      storeSlug: json['store_slug']?.toString(),
      storeLogo: json['store_logo']?.toString(),
      storeDescription: json['store_description']?.toString(),
      storeWilaya: json['store_wilaya']?.toString(),
      storeRating:
          double.tryParse(json['store_rating']?.toString() ?? '0') ?? 0,
      storeReviewCount:
          int.tryParse(json['store_review_count']?.toString() ?? '0') ?? 0,
      storeProductCount:
          int.tryParse(json['store_product_count']?.toString() ?? '0') ?? 0,
      followersCount:
          int.tryParse(json['followers_count']?.toString() ?? '0') ?? 0,
      followingCount:
          int.tryParse(json['following_count']?.toString() ?? '0') ?? 0,
      isFollowing: json['is_following'] == true ||
          json['is_following']?.toString() == 'true',
      createdAt: createdAtValue != null && createdAtValue.isNotEmpty
          ? DateTime.tryParse(createdAtValue)
          : null,
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final double totalAmount;
  final String status;
  final String? paymentMethod;
  final String? shippingAddress;
  final String? storeName;
  final List<OrderItem> items;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.orderNumber,
    required this.totalAmount,
    required this.status,
    this.paymentMethod,
    this.shippingAddress,
    this.storeName,
    this.items = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      orderNumber: json['order_number'] ?? '',
      totalAmount: double.tryParse(
              (json['total_amount'] ?? json['total'])?.toString() ?? '0') ??
          0,
      status: json['status'] ?? 'pending',
      paymentMethod: json['payment_method'],
      shippingAddress: json['shipping_address'],
      storeName: json['store_name'],
      items: json['items'] != null
          ? (json['items'] as List).map((i) => OrderItem.fromJson(i)).toList()
          : [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

class OrderItem {
  final String productName;
  final int quantity;
  final double price;

  OrderItem(
      {required this.productName, required this.quantity, required this.price});

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productName: json['product_name'] ?? '',
      quantity: json['quantity'] ?? 1,
      price: double.tryParse(
              (json['price'] ?? json['product_price'])?.toString() ?? '0') ??
          0,
    );
  }
}

class AppUser {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? avatar;
  final String role;
  final String? wilaya;

  AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.avatar,
    required this.role,
    this.wilaya,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      avatar: json['avatar']?.toString(),
      role: json['role'] ?? 'buyer',
      wilaya: json['wilaya'],
    );
  }
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.price * quantity;
}
