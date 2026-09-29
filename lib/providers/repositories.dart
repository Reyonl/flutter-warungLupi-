import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../models/models.dart';

/// Repository pelanggan — mirror `Api\CustomerController`.
class CustomerRepository {
  final Dio _dio = ApiClient.instance.dio;

  /// GET /api/customers?search=&is_active=
  Future<List<Customer>> index({String search = '', bool? isActive}) async {
    final params = <String, dynamic>{};
    if (search.trim().isNotEmpty) params['search'] = search.trim();
    if (isActive != null) params['is_active'] = isActive ? 1 : 0;
    final res = await _dio.get('/customers', queryParameters: params);
    final data = res.data;
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(Customer.fromJson).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(Customer.fromJson)
          .toList();
    }
    return [];
  }

  /// POST /api/customers
  Future<Customer> store({required String name, String? phone, String? notes}) async {
    final res = await _dio.post('/customers', data: {
      'name': name.trim(),
      'phone': (phone == null || phone.isEmpty) ? null : phone.trim(),
      'notes': (notes == null || notes.isEmpty) ? null : notes.trim(),
    });
    return Customer.fromJson(res.data is Map ? (res.data as Map).cast<String, dynamic>() : {});
  }

  /// GET /api/customers/{id}
  Future<Customer> show(int id) async {
    final res = await _dio.get('/customers/$id');
    return Customer.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// PUT /api/customers/{id}
  Future<Customer> update(
    int id, {
    String? name,
    String? phone,
    String? notes,
    bool? isActive,
  }) async {
    final res = await _dio.put('/customers/$id', data: {
      if (name != null) 'name': name.trim(),
      if (phone != null) 'phone': (phone.isEmpty) ? null : phone.trim(),
      if (notes != null) 'notes': (notes.isEmpty) ? null : notes.trim(),
      if (isActive != null) 'is_active': isActive,
    });
    return Customer.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// DELETE /api/customers/{id} — 422 jika punya transaksi (message di error)
  Future<void> destroy(int id) async {
    await _dio.delete('/customers/$id');
  }

  /// GET /api/customers/{id}/transactions
  Future<List<TransactionSummary>> transactions(int id) async {
    final res = await _dio.get('/customers/$id/transactions');
    final data = res.data;
    if (data is Map && data['transactions'] is List) {
      return (data['transactions'] as List)
          .whereType<Map<String, dynamic>>()
          .map(TransactionSummary.fromJson)
          .toList();
    }
    return [];
  }
}

/// Repository kategori — mirror `Api\CategoryController`.
class CategoryRepository {
  final Dio _dio = ApiClient.instance.dio;

  /// GET /api/categories (withCount products)
  Future<List<Category>> index() async {
    final res = await _dio.get('/categories');
    final data = res.data;
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(Category.fromJson).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(Category.fromJson)
          .toList();
    }
    return [];
  }

  /// POST /api/categories
  Future<Category> store(String name) async {
    final res = await _dio.post('/categories', data: {'name': name.trim()});
    return Category.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// PUT /api/categories/{id}
  Future<Category> update(int id, String name) async {
    final res = await _dio.put('/categories/$id', data: {'name': name.trim()});
    return Category.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// DELETE /api/categories/{id} — 422 jika masih punya products
  Future<void> destroy(int id) async {
    await _dio.delete('/categories/$id');
  }
}

/// Repository produk/item — mirror `Api\ProductController`.
class ProductRepository {
  final Dio _dio = ApiClient.instance.dio;

  /// GET /api/products?search=&category_id=&is_active=
  Future<List<Product>> index({String search = '', int? categoryId, bool? isActive}) async {
    final params = <String, dynamic>{};
    if (search.trim().isNotEmpty) params['search'] = search.trim();
    if (categoryId != null) params['category_id'] = categoryId;
    if (isActive != null) params['is_active'] = isActive ? 1 : 0;
    final res = await _dio.get('/products', queryParameters: params);
    final data = res.data;
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(Product.fromJson).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toList();
    }
    return [];
  }

  /// POST /api/products
  Future<Product> store({
    required int categoryId,
    required String name,
    required int defaultPrice,
    required String unit,
    bool isActive = true,
  }) async {
    final res = await _dio.post('/products', data: {
      'category_id': categoryId,
      'name': name.trim(),
      'default_price': defaultPrice,
      'unit': unit.trim(),
      'is_active': isActive,
    });
    return Product.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// PUT /api/products/{id}
  Future<Product> update(
    int id, {
    int? categoryId,
    String? name,
    int? defaultPrice,
    String? unit,
    bool? isActive,
  }) async {
    final res = await _dio.put('/products/$id', data: {
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name.trim(),
      if (defaultPrice != null) 'default_price': defaultPrice,
      if (unit != null) 'unit': unit.trim(),
      if (isActive != null) 'is_active': isActive,
    });
    return Product.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// DELETE /api/products/{id}
  Future<void> destroy(int id) async {
    await _dio.delete('/products/$id');
  }
}

/// Repository transaksi/bon — mirror `Api\TransactionController` + `TransactionItemController`.
class TransactionRepository {
  final Dio _dio = ApiClient.instance.dio;

  /// GET /api/transactions?search=&date_from=&date_to=&status=&customer_id=&page=
  Future<Paginated<Transaction>> index({
    String search = '',
    String? dateFrom,
    String? dateTo,
    String? status,
    int? customerId,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (search.trim().isNotEmpty) params['search'] = search.trim();
    if (dateFrom != null && dateFrom.isNotEmpty) params['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) params['date_to'] = dateTo;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (customerId != null) params['customer_id'] = customerId;
    final res = await _dio.get('/transactions', queryParameters: params);
    return Paginated<Transaction>.fromJson(
      (res.data as Map).cast<String, dynamic>(),
      Transaction.fromJson,
    );
  }

  /// POST /api/transactions — buat header bon (status draft)
  Future<Transaction> store({
    required int customerId,
    required String transactionDate, // yyyy-MM-dd
    String? notes,
  }) async {
    final res = await _dio.post('/transactions', data: {
      'customer_id': customerId,
      'transaction_date': transactionDate,
      'notes': (notes == null || notes.isEmpty) ? null : notes,
    });
    return Transaction.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// GET /api/transactions/{id} — lengkap (customer + items)
  Future<Transaction> show(int id) async {
    final res = await _dio.get('/transactions/$id');
    return Transaction.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// PUT /api/transactions/{id} — update header / status / payment_status
  Future<Transaction> update(
    int id, {
    int? customerId,
    String? transactionDate,
    String? status,
    String? paymentStatus,
    String? notes,
  }) async {
    final res = await _dio.put('/transactions/$id', data: {
      if (customerId != null) 'customer_id': customerId,
      if (transactionDate != null) 'transaction_date': transactionDate,
      if (status != null) 'status': status,
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (notes != null) 'notes': notes,
    });
    return Transaction.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// DELETE /api/transactions/{id}
  Future<void> destroy(int id) async {
    await _dio.delete('/transactions/$id');
  }

  /// POST /api/transactions/{id}/items — tambah item bon
  Future<TransactionItem> addItem(
    int transactionId, {
    int? productId,
    required String productName,
    String? description,
    required int quantity,
    String unit = 'pcs',
    required int unitPrice,
    int? subtotal,
  }) async {
    final res = await _dio.post('/transactions/$transactionId/items', data: {
      'product_id': productId,
      'product_name': productName,
      'description': (description == null || description.isEmpty) ? null : description,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      if (subtotal != null) 'subtotal': subtotal,
    });
    return TransactionItem.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// PUT /api/transaction-items/{id}
  Future<TransactionItem> updateItem(
    int itemId, {
    int? productId,
    String? productName,
    String? description,
    int? quantity,
    String? unit,
    int? unitPrice,
    int? subtotal,
  }) async {
    final res = await _dio.put('/transaction-items/$itemId', data: {
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (description != null) 'description': description,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (subtotal != null) 'subtotal': subtotal,
    });
    return TransactionItem.fromJson((res.data as Map).cast<String, dynamic>());
  }

  /// DELETE /api/transaction-items/{id}
  Future<void> deleteItem(int itemId) async {
    await _dio.delete('/transaction-items/$itemId');
  }
}

/// Repository dashboard — mirror `Api\DashboardController`.
class DashboardRepository {
  final Dio _dio = ApiClient.instance.dio;

  /// GET /api/dashboard
  Future<DashboardData> index() async {
    final res = await _dio.get('/dashboard');
    final json = (res.data as Map).cast<String, dynamic>();
    final stats = (json['stats'] as Map?)?.cast<String, dynamic>() ?? {};
    final recent = json['recent_transactions'] is List
        ? (json['recent_transactions'] as List)
            .whereType<Map<String, dynamic>>()
            .map(TransactionSummary.fromJson)
            .toList()
        : <TransactionSummary>[];

    // CATATAN: `SUM()` pada kolom DECIMAL di MySQL dikembalikan sebagai
    // **string** JSON (mis. "2195000"), bukan number. Jangan pakai
    // `as num` — gunakan numFrom yang menerima String numerik juga.
    return DashboardData(
      bonHariIni: numFrom(stats['bon_hari_ini']),
      totalHariIni: numFrom(stats['total_hari_ini']),
      lunasHariIni: numFrom(stats['lunas_hari_ini']),
      lunasTotal: numFrom(stats['lunas_total']),
      masihHutang: numFrom(stats['masih_hutang']),
      totalPelanggan: numFrom(stats['total_pelanggan']),
      recent: recent,
    );
  }
}

/// Data dashboard (padanan `stats` dari DashboardController).
class DashboardData {
  final int bonHariIni;
  final int totalHariIni;
  final int lunasHariIni;
  final int lunasTotal;
  final int masihHutang;
  final int totalPelanggan;
  final List<TransactionSummary> recent;

  const DashboardData({
    required this.bonHariIni,
    required this.totalHariIni,
    required this.lunasHariIni,
    required this.lunasTotal,
    required this.masihHutang,
    required this.totalPelanggan,
    required this.recent,
  });
}