import 'dart:convert';
import 'dart:typed_data';

import 'package:digit_data_model/data_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/data/repositories/remote/downsync.dart';
import 'package:health_campaign_field_worker_app/models/downsync/downsync.dart';

/// Answers every request with [respond]; records the posted bodies.
class _StubAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) respond;
  final List<RequestOptions> requests = [];

  _StubAdapter(this.respond);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

Future<ResponseBody> _json(Map<String, dynamic> body) async =>
    ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

DownsyncRemoteRepository _repo(_StubAdapter adapter) => DownsyncRemoteRepository(
      Dio()..httpClientAdapter = adapter,
      actionMap: {ApiOperation.search: 'https://api.test/downsync/_get'},
    );

final _query = DownsyncSearchModel(
  locality: 'WARD_1',
  offset: 0,
  limit: 0,
  projectId: 'root',
  isDeleted: true,
);

void main() {
  test('returns the whole response when the server sends file links', () async {
    final adapter = _StubAdapter((_) => _json({
          'DownloadLinks': [
            {'fileType': 'HOUSEHOLD', 'url': 'https://f/1', 'recordCount': 3},
          ],
        }));

    final result = await _repo(adapter).downSync(_query);

    final links = result['DownloadLinks'] as List;
    expect((links.single as Map)['url'], 'https://f/1');
  });

  test('returns the Downsync payload for a paginated response', () async {
    final adapter = _StubAdapter((_) => _json({
          'Downsync': {
            'DownsyncCriteria': {'totalCount': 12},
            'Households': [],
          },
        }));

    final result = await _repo(adapter).downSync(_query);

    expect(result['DownsyncCriteria'], {'totalCount': 12});
    expect(result.containsKey('Households'), isTrue);
  });

  test('a network failure returns {} instead of throwing', () async {
    // The count-check handler has no try/catch and treats {} as "check
    // failed"; a throw would leave its loader up and the manual-sync flag set.
    final adapter = _StubAdapter((options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ));

    final result = await _repo(adapter).downSync(_query);

    expect(result, isEmpty);
  });

  test('a response with neither shape is rejected', () async {
    final adapter = _StubAdapter((_) => _json({'Errors': []}));

    await expectLater(
      _repo(adapter).downSync(_query),
      throwsA(isA<InvalidApiResponseException>()),
    );
  });

  test('posts the criteria under DownsyncCriteria', () async {
    final adapter = _StubAdapter((_) => _json({'Downsync': {}}));

    await _repo(adapter).downSync(_query, offSet: 40, limit: 20);

    final sent = adapter.requests.single;
    expect(sent.queryParameters['offset'], 40);
    expect(sent.queryParameters['limit'], 20);
    expect(sent.queryParameters['includeDeleted'], true);
    final criteria = (sent.data as Map)['DownsyncCriteria'] as Map;
    expect(criteria['locality'], 'WARD_1');
    expect(criteria['projectId'], 'root');
  });
}
