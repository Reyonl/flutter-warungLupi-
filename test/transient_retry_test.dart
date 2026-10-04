// Unit test TransientFailureRetry: perilaku retry kegagalan sementara.
// Tidak menyentuh jaringan — memakai HttpClientAdapter palsu.
//
// Jalankan: flutter test test/transient_retry_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rekapan_warung/core/api/api_client.dart';

/// Adapter palsu: membalas status sesuai urutan [script]; entri terakhir
/// dipakai berulang untuk sisa request. Mencatat jumlah panggilan per method.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.script);

  final List<int> script;
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options.method);
    final code =
        script[calls.length <= script.length
            ? calls.length - 1
            : script.length - 1];
    final body = code >= 400
        ? '{"message":"transient-failure"}'
        : '{"ok":true,"calls":${calls.length}}';
    return ResponseBody.fromString(
      body,
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_ScriptedAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://fake.test/api'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(TransientFailureRetry(dio));
  return dio;
}

void main() {
  test('GET 403 → retry dan berhasil di percobaan kedua', () async {
    final adapter = _ScriptedAdapter([403, 200]);
    final res = await _dioWith(adapter).get('/transactions');
    expect(res.statusCode, 200);
    expect(adapter.calls.length, 2);
  });

  test('GET 500 beruntun → maks 3 percobaan lalu error diteruskan', () async {
    final adapter = _ScriptedAdapter([500]);
    await expectLater(
      _dioWith(adapter).get('/dashboard'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          500,
        ),
      ),
    );
    expect(adapter.calls.length, 3, reason: '1 awal + 2 retry');
  });

  test('POST TIDAK pernah di-retry (hindari bon rangkap)', () async {
    final adapter = _ScriptedAdapter([403]);
    await expectLater(
      _dioWith(adapter).post('/transactions', data: {'a': 1}),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls.length, 1, reason: 'POST cukup sekali percobaan');
  });

  test('PUT 429 → 1 retry (idempoten), bukan 2', () async {
    final adapter = _ScriptedAdapter([429, 200]);
    final res = await _dioWith(adapter).put('/transactions/1', data: {'x': 1});
    expect(res.statusCode, 200);
    expect(adapter.calls.length, 2);
  });

  test('PUT 429 terus → maks 2 percobaan lalu menyerah', () async {
    final adapter = _ScriptedAdapter([429]);
    await expectLater(
      _dioWith(adapter).put('/transactions/1', data: {'x': 1}),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls.length, 2);
  });

  test('404 bukan transient → diteruskan tanpa retry', () async {
    final adapter = _ScriptedAdapter([404]);
    await expectLater(
      _dioWith(adapter).get('/transactions/999999'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls.length, 1);
  });

  test('pesan 403 tidak lagi mengklaim "tidak memiliki akses"', () {
    final opts = RequestOptions(path: '/x');
    final err = DioException(
      type: DioExceptionType.badResponse,
      response: Response(statusCode: 403, requestOptions: opts),
      requestOptions: opts,
    );
    final msg = ApiClient.errorMessage(err);
    expect(
      msg.contains('tidak memiliki akses'),
      isFalse,
      reason: 'backend tanpa auth — 403 adalah infra, bukan hak akses',
    );
    expect(msg, contains('sementara'));
  });
}
