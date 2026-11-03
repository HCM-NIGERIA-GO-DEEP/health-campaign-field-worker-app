// T14 - the Beneficiary IDs download (UniqueIdBloc) sends the device's
// Settings.Secure.ANDROID_ID (android_id package) as the dispatch request's
// deviceUuid. It used to send device_info_plus's androidInfo.id, which is
// Build.ID: the firmware build string shared by every device on that firmware.
//
// Every entry point (Download, no-internet retry, id_count_popup, the
// limit-exceeded Re-fetch) dispatches FetchUniqueIdsEvent, so these drive the
// bloc through the real UniqueIdPoolRemoteRepository and a scripted server.
import 'dart:async';
import 'dart:convert';

import 'package:digit_data_model/data/repositories/package_repository/remote/unique_id_pool.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/blocs/unique_beneficiary_id/unique_id.dart';
import 'package:mocktail/mocktail.dart';

import 'support/unique_id_test_support.dart';

const _androidIdChannel = MethodChannel('android_id');
const _deviceInfoChannel =
    MethodChannel('dev.fluttercommunity.plus/device_info');
const _connectivityChannel =
    MethodChannel('dev.fluttercommunity.plus/connectivity');

const _buildId = 'TP1A.220624.014';
const _androidId = 'f3a9c1d27b4e8a60';

typedef _Reply = (int status, Map<String, dynamic> body);

/// One dispatch page as the server sends it (FetchLimit = IDs still to come).
_Reply _page(List<String> ids, {required int fetchLimit, int totalLimit = 10}) {
  return (
    200,
    {
      'UniqueBeneficiaryIds': [
        for (final id in ids)
          {
            'id': id,
            'status': 'DISPATCHED',
            'userUuid': 'server-user',
            'deviceUuid': 'server-device',
          },
      ],
      'FetchLimit': fetchLimit,
      'TotalLimit': totalLimit,
    }
  );
}

final _Reply _nothingLeft = _page([], fetchLimit: 0, totalLimit: 0);

/// The body the idgen service sends for a CustomException (HTTP 400).
_Reply _serverError(String code, String message) => (
      400,
      {
        'Errors': [
          {'code': code, 'message': message},
        ],
      }
    );

/// Replays [replies] in order (the last one repeats) and records each request.
class _ScriptedServer implements HttpClientAdapter {
  _ScriptedServer(List<_Reply> replies) : _replies = [...replies];

  final List<_Reply> _replies;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final reply = _replies.length > 1 ? _replies.removeAt(0) : _replies.first;
    return ResponseBody.fromString(
      jsonEncode(reply.$2),
      reply.$1,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// What device_info_plus 9.x reads from Build on Android (every non-nullable
/// field of AndroidDeviceInfo.fromMap).
Map<String, dynamic> _androidBuild() => {
      'version': {
        'codename': 'REL',
        'incremental': '1',
        'release': '13',
        'sdkInt': 33,
        'securityPatch': '2024-01-01',
      },
      'board': 'board',
      'bootloader': 'bootloader',
      'brand': 'brand',
      'device': 'device',
      'display': 'display',
      'fingerprint': 'fingerprint',
      'hardware': 'hardware',
      'host': 'host',
      'id': _buildId,
      'manufacturer': 'manufacturer',
      'model': 'model',
      'product': 'product',
      'supported32BitAbis': <String>[],
      'supported64BitAbis': <String>[],
      'supportedAbis': <String>[],
      'tags': 'release-keys',
      'type': 'user',
      'isPhysicalDevice': true,
      'systemFeatures': <String>[],
      'displayMetrics': {
        'widthPx': 720.0,
        'heightPx': 1600.0,
        'xDpi': 268.0,
        'yDpi': 268.0,
      },
      'serialNumber': 'unknown',
    };

void _mockChannel(
  MethodChannel channel,
  Future<Object?>? Function(MethodCall call)? handler,
) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, handler);
}

void _androidIdReturns(Object? value) {
  _mockChannel(_androidIdChannel, (call) async {
    expect(call.method, 'getId');
    if (value is Exception) throw value;
    return value;
  });
}

class _Run {
  _Run(this.requests, this.states, this.saved, this.localQueries);

  /// IdDispatchRequest bodies, in send order.
  final List<Map> requests;
  final List<UniqueIdState> states;

  /// Rows handed to the local repository's bulkCreate.
  final List<UniqueIdPoolModel> saved;
  final List<UniqueIdPoolSearchModel> localQueries;

  UniqueIdState get last => states.last;
}

/// Sends one event and waits for the bloc's first non-progress state.
Future<_Run> _run(
  UniqueIdEvent event, {
  List<_Reply>? replies,
}) async {
  final server = _ScriptedServer(replies ?? [_nothingLeft]);
  final saved = <UniqueIdPoolModel>[];
  final localQueries = <UniqueIdPoolSearchModel>[];
  final repo = MockUniqueIdPoolRepo();
  when(() => repo.search(any())).thenAnswer((invocation) async {
    localQueries
        .add(invocation.positionalArguments.first as UniqueIdPoolSearchModel);
    return [];
  });
  when(() => repo.bulkCreate(any())).thenAnswer((invocation) async {
    saved.addAll(
        invocation.positionalArguments.first as List<UniqueIdPoolModel>);
  });

  final bloc = UniqueIdBloc(
    uniqueIdPoolLocalRepository: repo,
    uniqueIdPoolRemoteRepository: UniqueIdPoolRemoteRepository(
      Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = server,
      actionMap: const {
        ApiOperation.search: '/id-gen/id/id_pool/_dispatch',
      },
    ),
    userUuid: 'U1',
    beneficiaryIdMinCount: 10,
    beneficiaryIdBatchSize: 5,
    tenantId: 'default',
  );

  final states = <UniqueIdState>[];
  final settled = Completer<void>();
  final subscription = bloc.stream.listen((state) {
    states.add(state);
    if (state is! FetchingState && state is! LoadingState) {
      if (!settled.isCompleted) settled.complete();
    }
  });
  bloc.add(event);
  // A hang (e.g. a platform call that never answers) fails here.
  await settled.future.timeout(const Duration(seconds: 5));
  await subscription.cancel();
  await bloc.close();

  return _Run(
    [
      for (final request in server.requests)
        (request.data as Map)['IdDispatchRequest'] as Map,
    ],
    states,
    saved,
    localQueries,
  );
}

Future<_Run> _download({bool? reFetch, List<_Reply>? replies}) =>
    _run(UniqueIdEvent.fetchUniqueIdsFromServer(reFetch: reFetch),
        replies: replies);

void main() {
  setUpAll(() {
    setUpUniqueIdFlow();
    registerFallbackValue(<UniqueIdPoolModel>[]);
  });

  setUp(() {
    _mockChannel(_deviceInfoChannel, (_) async => _androidBuild());
    _mockChannel(_connectivityChannel, (_) async => ['wifi']);
  });

  tearDown(() {
    _mockChannel(_androidIdChannel, null);
    _mockChannel(_deviceInfoChannel, null);
    _mockChannel(_connectivityChannel, null);
  });

  group('T14: deviceUuid source', () {
    test('the dispatch request carries ANDROID_ID, not Build.ID', () async {
      _androidIdReturns(_androidId);

      final run = await _download();

      expect(run.requests.single['deviceUuid'], _androidId);
      expect(run.requests.single['userUuid'], 'U1');
      expect(run.last, isA<FetchedUniqueIdsState>());
    });

    test('deviceInfo still comes from device_info_plus', () async {
      _androidIdReturns(_androidId);

      final run = await _download();

      expect(run.requests.single['deviceInfo'], isA<String>());
      expect(run.requests.single['deviceInfo'] as String, contains(_buildId),
          reason: 'deviceInfo is AndroidDeviceInfo.toString(), as before');
    });

    // Each fallback must still complete the download with Build.ID: a null
    // deviceUuid would fail the server's @NotNull and the local
    // UniqueIdPoolModel.companion's `deviceUuid!`.
    final fallbacks = <String, Object?>{
      'null (no ANDROID_ID)': null,
      'empty string': '',
      'the literal "unknown"': 'unknown',
      'PlatformException (read failed)':
          PlatformException(code: 'ERROR_GETTING_ID'),
      'MissingPluginException (plugin not registered on this engine)':
          MissingPluginException(),
    };
    fallbacks.forEach((name, value) {
      test('$name -> Build.ID, download still completes', () async {
        _androidIdReturns(value);

        final run = await _download();

        expect(run.requests.single['deviceUuid'], _buildId);
        expect(run.last, isA<FetchedUniqueIdsState>());
      });
    });

    test('device_info_plus failing still fails the download, as before',
        () async {
      _androidIdReturns(_androidId);
      _mockChannel(_deviceInfoChannel, (_) async {
        throw PlatformException(code: 'device_info');
      });

      final run = await _download();

      expect(run.requests, isEmpty);
      expect(run.last, isA<FailedState>());
    });
  });

  group('T14: download flows', () {
    test('a paged download sends ANDROID_ID on every page and stamps every row',
        () async {
      _androidIdReturns(_androidId);

      final run = await _download(replies: [
        _page(['SMC-01', 'SMC-02', 'SMC-03', 'SMC-04', 'SMC-05'],
            fetchLimit: 5),
        _page(['SMC-06', 'SMC-07', 'SMC-08', 'SMC-09', 'SMC-10'],
            fetchLimit: 0),
      ]);

      expect(run.requests, hasLength(2));
      expect(run.requests.map((r) => r['deviceUuid']), everyElement(_androidId));
      expect(run.saved, hasLength(10));
      expect(run.saved.map((row) => row.deviceUuid), everyElement(_androidId));
      expect(run.saved.map((row) => row.userUuid), everyElement('U1'));
      expect((run.last as FetchedUniqueIdsState).ids, hasLength(10));
    });

    test('Re-fetch (limit popup) asks for allocated IDs with ANDROID_ID',
        () async {
      _androidIdReturns(_androidId);

      final run = await _download(
        reFetch: true,
        replies: [_page(['SMC-01', 'SMC-02'], fetchLimit: 0)],
      );

      expect(run.requests.single['fetchAllocatedIds'], isTrue);
      expect(run.requests.single['deviceUuid'], _androidId);
      expect(run.saved.map((row) => row.deviceUuid), everyElement(_androidId));
      expect(run.last, isA<FetchedUniqueIdsState>());
    });

    // Upstream idgen looks allocated IDs up by user + deviceUuid, so after the
    // update a re-fetch finds nothing logged under the new value and answers
    // 400 "NO IDS Dispatched". The page must reach a terminal state (failed
    // toast, dialog closed), not hang in "fetching".
    test('Re-fetch answered with 400 NO IDS Dispatched -> failed, no hang',
        () async {
      _androidIdReturns(_androidId);

      final run = await _download(
        reFetch: true,
        replies: [
          _serverError('NO IDS Dispatched',
              'NO IDS Dispatched: No IDs found for the given user and device.'),
        ],
      );

      expect(run.last, isA<FailedState>());
      expect(run.saved, isEmpty);
    });

    test('a 2xx limit-exceeded error body still opens the limit popup',
        () async {
      _androidIdReturns(_androidId);

      final run = await _download(replies: [
        (
          200,
          {
            'Errors': [
              {
                'code': 'USER_DEVICE_LIMIT_EXCEEDED',
                'message': 'ID generation limit exceeded: Daily limit for '
                    'user: U1 and device: $_androidId exceeded.',
              },
            ],
          }
        ),
      ]);

      expect(run.last, isA<LimitExceeded>());
    });

    test('offline -> noInternet and nothing is sent', () async {
      _androidIdReturns(_androidId);
      _mockChannel(_connectivityChannel, (_) async => ['none']);

      final run = await _download();

      expect(run.requests, isEmpty);
      expect(run.last, isA<NoInternetState>());
    });
  });

  group('T14: local reads ignore deviceUuid', () {
    test('the download and the count never filter local rows by device',
        () async {
      _androidIdReturns(_androidId);

      final download = await _download();
      final count = await _run(const UniqueIdEvent.fetchIdCount());

      final queries = [...download.localQueries, ...count.localQueries];
      expect(queries, isNotEmpty);
      expect(queries.map((q) => q.deviceUuid), everyElement(isNull),
          reason: 'rows saved under the old Build.ID must still be counted');
      expect(count.last, isA<FetchedIdCountState>());
    });
  });
}
