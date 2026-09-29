/// Parsing angka yang tahan terhadap bentuk data dari backend Laravel.
///
/// MySQL mengembalikan hasil agregat (`SUM()`, `AVG()`) pada kolom DECIMAL
/// sebagai **string** JSON (mis. `"2195000"`), bukan number. Konversi
/// `value as num` langsung akan melempar `TypeError` dan mematikan seluruh
/// layar yang bersangkutan (gejala: dashboard gagal memuat / data tidak muncul).
/// Helper ini menerima int, double, maupun String numerik.
int numFrom(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? fallback;
  }
  return fallback;
}

/// Varian nullable dari [numFrom] — null tetap null (untuk kolom opsional).
int? numFromOrNull(dynamic v) => v == null ? null : numFrom(v);

/// Model Kategori — mirror tabel `categories`.
class Category {
  final int id;
  final String name;
  final int? productsCount; // dari withCount('products')
  final List<Product>? products; // dari show()

  const Category({
    required this.id,
    required this.name,
    this.productsCount,
    this.products,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: numFrom(json['id']),
      name: (json['name'] ?? '') as String,
      productsCount: json['products_count'] != null
          ? numFrom(json['products_count'])
          : (json['products'] is List ? (json['products'] as List).length : null),
      products: json['products'] is List
          ? (json['products'] as List)
              .whereType<Map<String, dynamic>>()
              .map(Product.fromJson)
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {'name': name};
}

/// Model Produk/Item — mirror tabel `products`.
class Product {
  final int id;
  final int? categoryId;
  final String name;
  final int defaultPrice;
  final String unit;
  final bool isActive;
  final Category? category; // nested dari with('category')

  const Product({
    required this.id,
    this.categoryId,
    required this.name,
    required this.defaultPrice,
    required this.unit,
    required this.isActive,
    this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: numFrom(json['id']),
      categoryId: numFromOrNull(json['category_id']),
      name: (json['name'] ?? '') as String,
      defaultPrice: numFrom(json['default_price']),
      unit: (json['unit'] ?? 'pcs') as String,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      category: json['category'] is Map
          ? Category.fromJson(json['category'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'category_id': categoryId,
        'name': name,
        'default_price': defaultPrice,
        'unit': unit,
        'is_active': isActive,
      };
}

/// Model Pelanggan — mirror tabel `customers`.
class Customer {
  final int id;
  final String name;
  final String? phone;
  final String? notes;
  final bool isActive;
  final int? transactionsCount; // dari loadCount('transactions')

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    required this.isActive,
    this.transactionsCount,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: numFrom(json['id']),
      name: (json['name'] ?? '') as String,
      phone: json['phone'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      transactionsCount: numFromOrNull(json['transactions_count']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': (phone == null || phone!.isEmpty) ? null : phone,
        'notes': (notes == null || notes!.isEmpty) ? null : notes,
      };
}

/// Model Item Bon — mirror tabel `transaction_items`.
class TransactionItem {
  final int id;
  final int? transactionId;
  final int? productId;
  final String productName;
  final String? description;
  final int quantity;
  final String unit;
  final int unitPrice;
  final int subtotal;

  const TransactionItem({
    required this.id,
    this.transactionId,
    this.productId,
    required this.productName,
    this.description,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.subtotal,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: numFrom(json['id']),
      transactionId: numFromOrNull(json['transaction_id']),
      productId: numFromOrNull(json['product_id']),
      productName: (json['product_name'] ?? '') as String,
      description: json['description'] as String?,
      quantity: numFrom(json['quantity'], fallback: 1),
      unit: (json['unit'] ?? 'pcs') as String,
      unitPrice: numFrom(json['unit_price']),
      subtotal: numFrom(json['subtotal']),
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'description': (description == null || description!.isEmpty) ? null : description,
        'quantity': quantity,
        'unit': unit,
        'unit_price': unitPrice,
        'subtotal': subtotal,
      };
}

/// Model Transaksi/Bon — mirror tabel `transactions`.
class Transaction {
  final int id;
  final int? customerId;
  final String transactionNumber;
  final String transactionDate; // yyyy-MM-dd (DATE dari Laravel)
  final int totalAmount;
  final String status; // draft | completed
  final String paymentStatus; // unpaid | paid
  final String? notes;
  final Customer? customer; // nested from with('customer')
  final List<TransactionItem> items; // nested from with('items')

  const Transaction({
    required this.id,
    this.customerId,
    required this.transactionNumber,
    required this.transactionDate,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    this.notes,
    this.customer,
    this.items = const [],
  });

  bool get isCompleted => status == 'completed';
  bool get isPaid => paymentStatus == 'paid';

  /// Salinan transaksi dengan item disusun ulang mengikuti [orderedIds]
  /// (id item dari atas ke bawah, hasil reorder manual di layar Buat/Edit Bon).
  ///
  /// Backend TIDAK menyimpan urutan (tabel `transaction_items` tidak punya
  /// kolom order/sort; `GET /transactions/{id}` selalu mengembalikan item
  /// berdasarkan `id`), jadi urutan ini hanya hidup untuk sesi berjalan —
  /// dipakai preview nota, cetak thermal, PDF, PNG, copy, dan RawBT.
  /// Id asing/sudah hilang dibuang; item yang belum punya urutan
  /// manual diletakkan di akhir sesuai urutan server.
  Transaction withItemOrder(List<int> orderedIds) {
    if (orderedIds.isEmpty || items.isEmpty) return this;
    final byId = <int, TransactionItem>{for (final it in items) it.id: it};
    final out = <TransactionItem>[];
    for (final id in orderedIds) {
      final it = byId.remove(id);
      if (it != null) out.add(it);
    }
    out.addAll(byId.values);
    return Transaction(
      id: id,
      customerId: customerId,
      transactionNumber: transactionNumber,
      transactionDate: transactionDate,
      totalAmount: totalAmount,
      status: status,
      paymentStatus: paymentStatus,
      notes: notes,
      customer: customer,
      items: out,
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: numFrom(json['id']),
      customerId: numFromOrNull(json['customer_id']),
      transactionNumber: (json['transaction_number'] ?? '') as String,
      transactionDate: (json['transaction_date'] ?? '').toString().substring(0, 10),
      totalAmount: numFrom(json['total_amount']),
      status: (json['status'] ?? 'draft') as String,
      paymentStatus: (json['payment_status'] ?? 'unpaid') as String,
      notes: json['notes'] as String?,
      customer: json['customer'] is Map
          ? Customer.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      items: json['items'] is List
          ? (json['items'] as List)
              .whereType<Map<String, dynamic>>()
              .map(TransactionItem.fromJson)
              .toList()
          : [],
    );
  }
}

/// Item ringan untuk daftar bon (Dashboard recent & Customer transactions).
class TransactionSummary {
  final int id;
  final String transactionNumber;
  final String transactionDate; // sudah 'd M Y' dari backend
  final int totalAmount;
  final String status;
  final String? paymentStatus;
  final String? customerName;

  const TransactionSummary({
    required this.id,
    required this.transactionNumber,
    required this.transactionDate,
    required this.totalAmount,
    required this.status,
    this.paymentStatus,
    this.customerName,
  });

  factory TransactionSummary.fromJson(Map<String, dynamic> json) {
    return TransactionSummary(
      id: numFrom(json['id']),
      transactionNumber: (json['transaction_number'] ?? '') as String,
      transactionDate: (json['transaction_date'] ?? '') as String,
      totalAmount: numFrom(json['total_amount']),
      status: (json['status'] ?? 'draft') as String,
      paymentStatus: json['payment_status'] as String?,
      customerName: json['customer_name'] as String?,
    );
  }
}

/// Helper untuk response Laravel paginator: `{ data: [...], current_page, last_page, ... }`
class Paginated<T> {
  final List<T> data;
  final int currentPage;
  final int lastPage;
  final int total;

  const Paginated({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final items = json['data'] is List
        ? (json['data'] as List).whereType<Map<String, dynamic>>().map(fromJson).toList()
        : <T>[];
    return Paginated(
      data: items,
      currentPage: numFrom(json['current_page'], fallback: 1),
      lastPage: numFrom(json['last_page'], fallback: 1),
      total: numFrom(json['total'], fallback: items.length),
    );
  }
}