class User {
  final int id;
  final String username;
  final String nickname;
  final String role;
  final bool isActive;

  User({
    required this.id,
    required this.username,
    required this.nickname,
    required this.role,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class House {
  final int id;
  final int userId;
  final String name;
  final String icon;
  final int sortOrder;
  final bool isActive;

  House({
    required this.id,
    required this.userId,
    required this.name,
    required this.icon,
    required this.sortOrder,
    this.isActive = true,
  });

  factory House.fromJson(Map<String, dynamic> json) {
    return House(
      id: json['id'] as int,
      userId: json['user_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '🏠',
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'icon': icon,
        'sort_order': sortOrder,
        'is_active': isActive,
      };
}

class Room {
  final int id;
  final int userId;
  final int houseId;
  final String name;
  final String icon;
  final int sortOrder;
  final bool isActive;

  Room({
    required this.id,
    required this.userId,
    required this.houseId,
    required this.name,
    required this.icon,
    required this.sortOrder,
    this.isActive = true,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as int,
      userId: json['user_id'] as int? ?? 0,
      houseId: json['house_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '🛋️',
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'house_id': houseId,
        'name': name,
        'icon': icon,
        'sort_order': sortOrder,
        'is_active': isActive,
      };
}

class Category {
  final int id;
  final String name;
  final String icon;
  final int sortOrder;
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '📦',
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'sort_order': sortOrder,
        'is_active': isActive,
      };
}

class Tag {
  final int id;
  final String name;

  Tag({required this.id, required this.name});

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class Attachment {
  final int id;
  final int itemId;
  final String mediaType;
  final String filePath;
  final String url;
  final String? thumbnailUrl;
  final int fileSize;
  final int durationSeconds;
  final int width;
  final int height;

  Attachment({
    required this.id,
    required this.itemId,
    required this.mediaType,
    required this.filePath,
    required this.url,
    this.thumbnailUrl,
    required this.fileSize,
    required this.durationSeconds,
    this.width = 0,
    this.height = 0,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as int? ?? 0,
      itemId: json['item_id'] as int? ?? 0,
      mediaType: json['media_type'] as String? ?? 'image',
      filePath: json['file_path'] as String? ?? '',
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      fileSize: json['file_size'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_id': itemId,
        'media_type': mediaType,
        'file_path': filePath,
        'url': url,
        'thumbnail_url': thumbnailUrl,
        'file_size': fileSize,
        'duration_seconds': durationSeconds,
        'width': width,
        'height': height,
      };
}

class Item {
  final int id;
  final int userId;
  final int houseId;
  final int roomId;
  final int? categoryId;
  final String name;
  final String brand;
  final int quantity;
  final String locationDetail;
  final String description;
  final int version;
  final House? house;
  final Room? room;
  final Category? category;
  final List<Tag> tags;
  final List<Attachment> attachments;
  final String? pathDisplay;

  Item({
    required this.id,
    required this.userId,
    required this.houseId,
    required this.roomId,
    this.categoryId,
    required this.name,
    required this.brand,
    required this.quantity,
    required this.locationDetail,
    required this.description,
    this.version = 1,
    this.house,
    this.room,
    this.category,
    this.tags = const [],
    this.attachments = const [],
    this.pathDisplay,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as int,
      userId: json['user_id'] as int? ?? 0,
      houseId: json['house_id'] as int? ?? 0,
      roomId: json['room_id'] as int? ?? 0,
      categoryId: json['category_id'] as int?,
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      locationDetail: json['location_detail'] as String? ?? '',
      description: json['description'] as String? ?? '',
      version: json['version'] as int? ?? 1,
      house: json['house'] != null ? House.fromJson(json['house']) : null,
      room: json['room'] != null ? Room.fromJson(json['room']) : null,
      category: json['category'] != null ? Category.fromJson(json['category']) : null,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => Tag.fromJson(e)).toList() ?? [],
      attachments: (json['attachments'] as List<dynamic>?)?.map((e) => Attachment.fromJson(e)).toList() ?? [],
      pathDisplay: json['path_display'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'house_id': houseId,
        'room_id': roomId,
        'category_id': categoryId,
        'name': name,
        'brand': brand,
        'quantity': quantity,
        'location_detail': locationDetail,
        'description': description,
        'version': version,
        if (house != null) 'house': house!.toJson(),
        if (room != null) 'room': room!.toJson(),
        if (category != null) 'category': category!.toJson(),
        'tags': tags.map((t) => t.toJson()).toList(),
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'path_display': pathDisplay,
      };
}

