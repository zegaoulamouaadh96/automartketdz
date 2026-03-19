import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrlFromEnv =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _remoteBaseUrl = 'http://5.135.79.223:3001/api';

  static String get baseUrl {
    if (_baseUrlFromEnv.isNotEmpty) {
      return _baseUrlFromEnv;
    }

    // Default to public server reachable worldwide
    return _remoteBaseUrl;
  }

  static String get serverOrigin {
    final uri = Uri.parse(baseUrl);
    final hasCustomPort = (uri.scheme == 'http' && uri.port != 80) ||
        (uri.scheme == 'https' && uri.port != 443);
    return '${uri.scheme}://${uri.host}${hasCustomPort ? ':${uri.port}' : ''}';
  }

  static String resolveMediaUrl(String? path) {
    if (path == null || path.trim().isEmpty) {
      return '';
    }

    var normalized = path.trim().replaceAll('\\', '/');
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }

    if (!normalized.startsWith('/uploads/')) {
      normalized = '/uploads/${normalized.replaceFirst('/', '')}';
    }

    return '$serverOrigin$normalized';
  }

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await _getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Auth
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> register(
      Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final res = await http.get(
      Uri.parse('$baseUrl/auth/profile'),
      headers: await _headers(auth: true),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/auth/profile'),
      headers: await _headers(auth: true),
      body: jsonEncode(data),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> uploadProfileAvatar(
      String filePath) async {
    final req =
        http.MultipartRequest('PUT', Uri.parse('$baseUrl/auth/profile/avatar'));
    final headers = await _headers(auth: true);
    headers.remove('Content-Type');
    req.headers.addAll(headers);
    req.files.add(await http.MultipartFile.fromPath('avatar', filePath));

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> removeProfileAvatar() async {
    final res = await http.put(
      Uri.parse('$baseUrl/auth/profile/avatar'),
      headers: await _headers(auth: true),
      body: jsonEncode({'remove_avatar': true}),
    );
    return _handleResponse(res);
  }

  // Products
  static Future<Map<String, dynamic>> getProducts({
    int page = 1,
    int limit = 20,
    String? category,
    String? search,
    String? sort,
    String? condition,
    String? brand,
    String? model,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (category != null) params['category'] = category;
    if (search != null) params['search'] = search;
    if (sort != null) params['sort'] = sort;
    if (condition != null) params['condition'] = condition;
    if (brand != null) params['brand'] = brand;
    if (model != null) params['model'] = model;

    final uri = Uri.parse('$baseUrl/products').replace(queryParameters: params);
    final res = await http.get(uri, headers: await _headers());
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getProduct(String id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/products/$id'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> searchProducts(String query) async {
    final res = await http.get(
      Uri.parse('$baseUrl/products/search?q=$query'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  // Announcements
  static Future<Map<String, dynamic>> getAnnouncements() async {
    final res = await http.get(
      Uri.parse('$baseUrl/announcements'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  // Notifications (user)
  static Future<Map<String, dynamic>> getNotifications() async {
    final res = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: await _headers(auth: true),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> markNotificationRead(String id) async {
    final res = await http.put(
      Uri.parse('$baseUrl/notifications/$id/read'),
      headers: await _headers(auth: true),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> markAllNotificationsRead() async {
    final res = await http.put(
      Uri.parse('$baseUrl/notifications/all/read'),
      headers: await _headers(auth: true),
    );
    return _handleResponse(res);
  }

  // App Settings (public)
  static Future<Map<String, dynamic>> getAppSettings() async {
    final res = await http.get(
      Uri.parse('$baseUrl/app-settings'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  // Categories
  static Future<Map<String, dynamic>> getCategories() async {
    final res = await http.get(
      Uri.parse('$baseUrl/categories'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  // Brands
  static Future<Map<String, dynamic>> getBrands({String? vehicleType}) async {
    final params = <String, String>{};
    if (vehicleType != null) params['vehicle_type'] = vehicleType;
    final uri = Uri.parse('$baseUrl/vehicle-brands')
        .replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await http.get(uri, headers: await _headers());
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getVehicleModels(String brandId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/vehicle-brands/$brandId/models'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getVehicleYears(String modelId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/vehicle-models/$modelId/years'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  // Stores
  static Future<Map<String, dynamic>> getStore(String idOrSlug) async {
    final res = await http.get(
      Uri.parse('$baseUrl/stores/$idOrSlug'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getStores({
    int page = 1,
    int limit = 20,
    String? search,
    String? wilaya,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (wilaya != null && wilaya.trim().isNotEmpty) {
      params['wilaya'] = wilaya.trim();
    }

    final uri = Uri.parse('$baseUrl/stores').replace(queryParameters: params);
    final res = await http.get(
      uri,
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> searchUsers({
    String? search,
    int limit = 20,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }

    final uri =
        Uri.parse('$baseUrl/users/search').replace(queryParameters: params);
    final res = await http.get(uri, headers: await _headers(auth: true));
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getPublicUserProfile(
      String userId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/users/$userId/public-profile'),
      headers: await _headers(auth: true),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> followUser(String userId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/$userId/follow'),
      headers: await _headers(auth: true),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> unfollowUser(String userId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/users/$userId/follow'),
      headers: await _headers(auth: true),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getMyStore() async {
    final res = await http.get(
      Uri.parse('$baseUrl/stores/my-store'),
      headers: await _headers(auth: true),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> createStore(
      Map<String, dynamic> data) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/stores'));
    req.headers.addAll(await _headers(auth: true));
    req.files.clear();

    data.forEach((key, value) {
      if (value != null && key != 'logo_path') {
        req.fields[key] = value.toString();
      }
    });

    final logoPath = data['logo_path']?.toString();
    if (logoPath != null && logoPath.isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath('logo', logoPath));
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getSellerStats() async {
    final res = await http.get(
      Uri.parse('$baseUrl/stores/my-store/stats'),
      headers: await _headers(auth: true),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getMyProducts(
      {int page = 1, int limit = 30}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/products/my-products?page=$page&limit=$limit'),
      headers: await _headers(auth: true),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> createProduct(
      Map<String, dynamic> data) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/products'));
    final headers = await _headers(auth: true);
    headers.remove('Content-Type');
    req.headers.addAll(headers);

    data.forEach((key, value) {
      if (value == null) return;
      if (key == 'images_paths' || key == 'fitments' || key == 'oem_numbers')
        return;
      req.fields[key] = value.toString();
    });

    final fitments = data['fitments'];
    if (fitments != null) {
      req.fields['fitments'] = jsonEncode(fitments);
    }

    final oemNumbers = data['oem_numbers'];
    if (oemNumbers != null) {
      req.fields['oem_numbers'] = jsonEncode(oemNumbers);
    }

    final imagePaths = data['images_paths'];
    if (imagePaths is List) {
      for (final path in imagePaths) {
        final p = path?.toString();
        if (p != null && p.isNotEmpty) {
          req.files.add(await http.MultipartFile.fromPath('images', p));
        }
      }
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> updateProduct(
      String id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/products/$id'),
      headers: await _headers(auth: true),
      body: jsonEncode(data),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> deleteProduct(String id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/products/$id'),
      headers: await _headers(auth: true),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getStoreOrders({
    int page = 1,
    String? status,
  }) async {
    final params = <String, String>{'page': '$page'};
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    final uri = Uri.parse('$baseUrl/orders/store-orders')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: await _headers(auth: true));
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> updateOrderStatus(
      String id, String status,
      {String? cancelledReason}) async {
    final body = <String, dynamic>{'status': status};
    if (cancelledReason != null && cancelledReason.isNotEmpty) {
      body['cancelled_reason'] = cancelledReason;
    }
    final res = await http.patch(
      Uri.parse('$baseUrl/orders/$id/status'),
      headers: await _headers(auth: true),
      body: jsonEncode(body),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getStoreReviews(String storeId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/reviews/stores/$storeId'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  // Orders
  static Future<Map<String, dynamic>> createOrder(
      Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/orders'),
      headers: await _headers(auth: true),
      body: jsonEncode(data),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getOrders({int page = 1}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/orders?page=$page'),
      headers: await _headers(auth: true),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getOrder(String id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/orders/$id'),
      headers: await _headers(auth: true),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> cancelOrder(String id) async {
    final res = await http.put(
      Uri.parse('$baseUrl/orders/$id/status'),
      headers: await _headers(auth: true),
      body: jsonEncode({'status': 'cancelled'}),
    );
    return _handleResponse(res);
  }

  // Reviews
  static Future<Map<String, dynamic>> getProductReviews(
      String productId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/reviews/products/$productId'),
      headers: await _headers(),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> addProductReview({
    required String productId,
    required int rating,
    String? comment,
  }) async {
    final body = <String, dynamic>{'rating': rating};
    if (comment != null && comment.trim().isNotEmpty) {
      body['comment'] = comment.trim();
    }

    final res = await http.post(
      Uri.parse('$baseUrl/reviews/products/$productId'),
      headers: await _headers(auth: true),
      body: jsonEncode(body),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> addStoreReview({
    required String storeId,
    required int rating,
    String? comment,
  }) async {
    final body = <String, dynamic>{'rating': rating};
    if (comment != null && comment.trim().isNotEmpty) {
      body['comment'] = comment.trim();
    }

    final res = await http.post(
      Uri.parse('$baseUrl/reviews/stores/$storeId'),
      headers: await _headers(auth: true),
      body: jsonEncode(body),
    );
    return _handleResponse(res);
  }

  // Chat
  static Future<Map<String, dynamic>> getConversations() async {
    final res = await http.get(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: await _headers(auth: true),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getMessages(String conversationId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/chat/conversations/$conversationId/messages'),
      headers: await _headers(auth: true),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    String? productId,
    String? conversationId,
    required String message,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/chat/messages'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'receiver_id': receiverId,
        'product_id': productId,
        'conversation_id': conversationId,
        'content': message,
      }),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> sendImageMessage({
    required String receiverId,
    String? productId,
    String? conversationId,
    String? content,
    required String imageUrl,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/chat/messages'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'receiver_id': receiverId,
        'product_id': productId,
        'conversation_id': conversationId,
        'content': content ?? '',
        'image_url': imageUrl,
      }),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> sendVoiceMessage({
    required String receiverId,
    String? productId,
    String? conversationId,
    String? content,
    required String audioUrl,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/chat/messages'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'receiver_id': receiverId,
        'product_id': productId,
        'conversation_id': conversationId,
        'content': content ?? '',
        'audio_url': audioUrl,
      }),
    );
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> uploadChatImage(String filePath) async {
    final req =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/chat/upload-image'));
    final headers = await _headers(auth: true);
    headers.remove('Content-Type');
    req.headers.addAll(headers);
    req.files.add(await http.MultipartFile.fromPath('image', filePath));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> uploadChatMedia(String filePath) async {
    final req =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/chat/upload-media'));
    final headers = await _headers(auth: true);
    headers.remove('Content-Type');
    req.headers.addAll(headers);
    req.files.add(await http.MultipartFile.fromPath('media', filePath));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _handleResponse(res);
  }

  static Future<Map<String, dynamic>> startConversation(
      String sellerId, String message,
      {String? productId}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: await _headers(auth: true),
      body: jsonEncode(
          {'seller_id': sellerId, 'product_id': productId, 'message': message}),
    );
    return _handleResponse(res);
  }

  static Future<String> ensureConversationWithUser(
    String userId, {
    String initialMessage = 'مرحبا، أود التواصل معك.',
  }) async {
    final conversationsRes = await getConversations();
    final conversations =
        conversationsRes['data'] ?? conversationsRes['conversations'] ?? [];

    if (conversations is List) {
      for (final item in conversations) {
        if (item is! Map) continue;
        final otherUserId =
            (item['other_user_id'] ?? item['otherUserId'])?.toString();
        if (otherUserId == userId) {
          final existingId =
              (item['id'] ?? item['conversation_id'])?.toString() ?? '';
          if (existingId.isNotEmpty) {
            return existingId;
          }
        }
      }
    }

    final created = await sendMessage(
      receiverId: userId,
      message: initialMessage,
    );

    final directId = (created['conversation_id'] ??
            (created['conversation'] is Map
                ? created['conversation']['id']
                : null) ??
            (created['message'] is Map
                ? created['message']['conversation_id']
                : null))
        ?.toString();

    if (directId != null && directId.isNotEmpty) {
      return directId;
    }

    throw ApiException('تعذر فتح المحادثة حالياً', 500);
  }

  // Wilayas
  static Future<Map<String, dynamic>> getWilayas() async {
    final res = await http.get(Uri.parse('$baseUrl/wilayas'),
        headers: await _headers());
    return _handleResponse(res);
  }

  static Map<String, dynamic> _handleResponse(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    } else {
      String message;
      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty && errors.first is Map) {
        final firstError = errors.first as Map;
        message =
            (firstError['msg'] ?? firstError['message'] ?? 'خطأ في المدخلات')
                .toString();
      } else {
        message =
            (body['error'] ?? body['message'] ?? 'خطأ في الخادم').toString();
      }

      throw ApiException(message, res.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}
