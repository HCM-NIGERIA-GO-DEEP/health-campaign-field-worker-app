// RC-15 (client side): a pool download writes each row with the logged-in
// user's uuid and with the server's status, unless the server says ASSIGNED
// (remote/unique_id_pool.dart:84-93). Because the client never reports
// ASSIGNED to the server, a re-fetch can bring back an ID that was already
// used on another device, or earlier on this one, as UN_ASSIGNED.
//
// Production change that would flip this: the client keeping its local
// ASSIGNED status on re-fetch (or the sync reporting assignments).
import 'dart:convert';
import 'dart:typed_data';

import 'package:digit_data_model/data/repositories/package_repository/remote/unique_id_pool.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/unique_id_test_support.dart';

class _FixedJsonAdapter implements HttpClientAdapter {
  _FixedJsonAdapter(this.body);
  final Map<String, dynamic> body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(initTestEnv);

  test('downloaded rows take the query user and the server status', () async {
    final adapter = _FixedJsonAdapter({
      'UniqueBeneficiaryIds': [
        {'id': 'X', 'status': 'UN_ASSIGNED', 'userUuid': 'server-user', 'deviceUuid': 'other-device'},
        {'id': 'Y', 'status': 'ASSIGNED', 'userUuid': 'server-user', 'deviceUuid': 'other-device'},
        {'id': 'Z', 'status': 'DISPATCHED', 'userUuid': 'server-user', 'deviceUuid': 'other-device'},
      ],
      'FetchLimit': 0,
      'TotalLimit': 3,
    });
    final dio = Dio()..httpClientAdapter = adapter;
    final repo = UniqueIdPoolRemoteRepository(
      dio,
      actionMap: const {ApiOperation.search: '/id-gen/id/id_pool/_dispatch'},
    );

    final response = await repo.searchWithMetadata(
      UniqueIdPoolSearchModel(
        userUuid: 'U2',
        deviceUuid: 'D2',
        count: 10,
        fetchAllocatedIds: true,
      ),
    );

    expect(response.totalLimit, 3);
    final byId = {for (final m in response.models) m.id: m};
    expect(byId['X']!.status, 'UN_ASSIGNED');
    expect(byId['Y']!.status, 'ASSIGNED', reason: 'only ASSIGNED survives');
    expect(byId['Z']!.status, 'UN_ASSIGNED',
        reason: 'any other server status becomes UN_ASSIGNED (:87-89)');
    for (final m in response.models) {
      expect(m.userUuid, 'U2', reason: 'rows belong to the downloading user');
      expect(m.deviceUuid, 'D2');
    }

    final sent = adapter.lastRequest!;
    expect(sent.path, '/id-gen/id/id_pool/_dispatch');
    final body = sent.data as Map;
    final criteria = body['IdDispatchRequest'] as Map;
    expect(criteria['fetchAllocatedIds'], true,
        reason: 'the Re-fetch button asks for already allocated IDs');
  });
}
