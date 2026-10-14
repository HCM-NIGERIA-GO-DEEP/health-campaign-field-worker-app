import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart' as data_model_mappers;
import 'package:digit_data_model/models/entities/hf_referral.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/services/beneficiary_file_downsync_importer.dart';
import 'package:survey_form/models/entities/service.dart';

class _RecordingRepo<D extends EntityModel, R extends EntitySearchModel>
    extends Fake implements LocalRepository<D, R> {
  final List<List<D>> batches = [];

  List<D> get all => batches.expand((b) => b).toList();

  @override
  FutureOr<void> bulkCreate(List<D> entities) {
    batches.add(List.of(entities));
  }
}

/// Serves each URL from a queue of scripted attempts, so a test can make the
/// first attempt drop mid-stream and the second one succeed.
class _ScriptedAdapter implements HttpClientAdapter {
  final Map<String, List<Stream<Uint8List> Function()>> attempts;
  final Map<String, int> calls = {};

  _ScriptedAdapter(this.attempts);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    final n = calls[url] = (calls[url] ?? 0) + 1;
    final queue = attempts[url]!;
    final body = queue[(n - 1).clamp(0, queue.length - 1)]();
    return ResponseBody(body, 200);
  }

  @override
  void close({bool force = false}) {}
}

Stream<Uint8List> _bytes(List<int> bytes, {int chunk = 7}) async* {
  for (var i = 0; i < bytes.length; i += chunk) {
    yield Uint8List.fromList(
        bytes.sublist(i, i + chunk > bytes.length ? bytes.length : i + chunk));
  }
}

Stream<Uint8List> _text(String text) => _bytes(utf8.encode(text));

/// Emits [text] then fails the way dart:io does when the server drops the
/// connection mid-body — dio 5.7 forwards this error unwrapped.
Stream<Uint8List> _dropAfter(String text) async* {
  yield* _text(text);
  throw const HttpException('Connection closed while receiving data');
}

String _ndjson(List<Map<String, dynamic>> rows) =>
    rows.map(jsonEncode).join('\n');

Map<String, dynamic> _hh(String id) =>
    {'_t': 'HOUSEHOLD', 'clientReferenceId': id};

Map<String, dynamic> _member(String id) => {
      '_t': 'HOUSEHOLD_MEMBER',
      'clientReferenceId': id,
      'isHeadOfHousehold': false,
    };

Map<String, dynamic> _ind(String id) =>
    {'_t': 'INDIVIDUAL', 'clientReferenceId': id};

Map<String, dynamic> _task(String id, {String type = 'TASK'}) =>
    {'_t': type, 'clientReferenceId': id};

void main() {
  setUpAll(() {
    data_model_mappers.initializeMappers();
  });

  late _RecordingRepo<IndividualModel, IndividualSearchModel> individuals;
  late _RecordingRepo<HouseholdModel, HouseholdSearchModel> households;
  late _RecordingRepo<HouseholdMemberModel, HouseholdMemberSearchModel>
      members;
  late _RecordingRepo<ProjectBeneficiaryModel, ProjectBeneficiarySearchModel>
      beneficiaries;
  late _RecordingRepo<TaskModel, TaskSearchModel> tasks;
  late _RecordingRepo<SideEffectModel, SideEffectSearchModel> sideEffects;
  late _RecordingRepo<ReferralModel, ReferralSearchModel> referrals;
  late _RecordingRepo<HFReferralModel, HFReferralSearchModel> hfReferrals;
  late _RecordingRepo<ServiceModel, ServiceSearchModel> services;

  setUp(() {
    individuals = _RecordingRepo();
    households = _RecordingRepo();
    members = _RecordingRepo();
    beneficiaries = _RecordingRepo();
    tasks = _RecordingRepo();
    sideEffects = _RecordingRepo();
    referrals = _RecordingRepo();
    hfReferrals = _RecordingRepo();
    services = _RecordingRepo();
  });

  BeneficiaryFileDownsyncImporter importerFor(
    _ScriptedAdapter adapter, {
    int? batchSize,
    Duration minLinkDuration = Duration.zero,
    Future<void> Function(Duration)? wait,
    DateTime Function()? now,
  }) {
    final dio = Dio()..httpClientAdapter = adapter;
    return BeneficiaryFileDownsyncImporter(
      dio: dio,
      individualLocalRepository: individuals,
      householdLocalRepository: households,
      householdMemberLocalRepository: members,
      projectBeneficiaryLocalRepository: beneficiaries,
      taskLocalRepository: tasks,
      sideEffectLocalRepository: sideEffects,
      referralLocalRepository: referrals,
      hfReferralLocalRepository: hfReferrals,
      serviceLocalRepository: services,
      batchSize: batchSize,
      downloadRetryDelay: Duration.zero,
      minLinkDuration: minLinkDuration,
      wait: wait,
      now: now,
    );
  }

  BeneficiaryDownloadLink link(String url, int count, {String type = ''}) =>
      BeneficiaryDownloadLink(fileType: type, url: url, recordCount: count);

  group('BeneficiaryFileDownsyncImporter.importLinks', () {
    test('writes each NDJSON line to the repository of its _t type', () async {
      const url = 'https://files.test/a.ndjson';
      final adapter = _ScriptedAdapter({
        url: [
          () => _text(_ndjson([_hh('h1'), _ind('i1'), _task('t1'), _hh('h2')]))
        ],
      });

      final result = await importerFor(adapter).importLinks([link(url, 4)]);

      expect(households.all.map((e) => e.clientReferenceId), ['h1', 'h2']);
      expect(individuals.all.map((e) => e.clientReferenceId), ['i1']);
      expect(tasks.all.map((e) => e.clientReferenceId), ['t1']);
      expect(result.importedCount, 4);
      expect(result.importedByType, {'HOUSEHOLD': 2, 'INDIVIDUAL': 1, 'TASK': 1});
    });

    test('reads a gzip-compressed file the same as plain text', () async {
      const url = 'https://files.test/a.ndjson.gz';
      final gz = gzip.encode(utf8.encode(_ndjson([_hh('h1'), _ind('i1')])));
      final adapter = _ScriptedAdapter({
        url: [() => _bytes(gz, chunk: 5)]
      });

      await importerFor(adapter).importLinks([link(url, 2)]);

      expect(households.all.map((e) => e.clientReferenceId), ['h1']);
      expect(individuals.all.map((e) => e.clientReferenceId), ['i1']);
    });

    test('stores PROJECT_TASK lines as tasks', () async {
      const url = 'https://files.test/t.ndjson';
      final adapter = _ScriptedAdapter({
        url: [() => _text(_ndjson([_task('t9', type: 'PROJECT_TASK')]))]
      });

      await importerFor(adapter).importLinks([link(url, 1)]);

      expect(tasks.all.map((e) => e.clientReferenceId), ['t9']);
    });

    test('skips unknown types, blank lines and non-object lines', () async {
      const url = 'https://files.test/mixed.ndjson';
      final body = [
        jsonEncode(_hh('h1')),
        '',
        '   ',
        jsonEncode({'_t': 'USER_ACTION', 'clientReferenceId': 'u1'}),
        jsonEncode([1, 2]),
        jsonEncode(_ind('i1')),
      ].join('\n');
      final adapter = _ScriptedAdapter({
        url: [() => _text(body)]
      });

      final result = await importerFor(adapter).importLinks([link(url, 4)]);

      expect(households.all.map((e) => e.clientReferenceId), ['h1']);
      expect(individuals.all.map((e) => e.clientReferenceId), ['i1']);
      expect(tasks.all, isEmpty);
      // Every non-blank line advances the position — the same rule the
      // resume skip uses — so a resume skips exactly the lines already read.
      expect(result.importedCount, 4);
      expect(result.importedByType, {'HOUSEHOLD': 1, 'USER_ACTION': 1, 'INDIVIDUAL': 1});
    });

    test('a resume skips exactly the non-blank lines already read', () async {
      const url = 'https://files.test/resume.ndjson';
      final body = [
        jsonEncode(_hh('h1')),
        '',
        jsonEncode([1, 2]),
        jsonEncode(_hh('h2')),
        jsonEncode(_hh('h3')),
      ].join('\n');
      final adapter = _ScriptedAdapter({
        url: [() => _text(body)]
      });

      await importerFor(adapter)
          .importLinks([link(url, 4)], startFromOffset: 2);

      expect(households.all.map((e) => e.clientReferenceId), ['h2', 'h3']);
    });

    test('flushes to the database in batches of batchSize', () async {
      const url = 'https://files.test/hh.ndjson';
      final adapter = _ScriptedAdapter({
        url: [
          () => _text(_ndjson([for (var i = 1; i <= 5; i++) _hh('h$i')]))
        ],
      });

      await importerFor(adapter, batchSize: 2).importLinks([link(url, 5)]);

      expect(households.batches.map((b) => b.length), [2, 2, 1]);
    });

    test('startFromOffset skips a fully imported link and the first lines of '
        'the next', () async {
      const first = 'https://files.test/1.ndjson';
      const second = 'https://files.test/2.ndjson';
      final adapter = _ScriptedAdapter({
        first: [() => _text(_ndjson([_hh('h1'), _hh('h2')]))],
        second: [
          () => _text(_ndjson([_ind('i1'), _ind('i2'), _ind('i3')]))
        ],
      });

      final result = await importerFor(adapter).importLinks(
        [link(first, 2), link(second, 3)],
        startFromOffset: 3,
      );

      expect(adapter.calls[first], isNull,
          reason: 'a link wholly covered by the offset is not downloaded');
      expect(households.all, isEmpty);
      expect(individuals.all.map((e) => e.clientReferenceId), ['i2', 'i3']);
      expect(result.importedCount, 5);
    });

    test('a mid-stream connection drop is retried without duplicating lines',
        () async {
      const url = 'https://files.test/drop.ndjson';
      final full = _ndjson([_hh('h1'), _hh('h2'), _hh('h3')]);
      final adapter = _ScriptedAdapter({
        url: [
          () => _dropAfter('${jsonEncode(_hh('h1'))}\n'),
          () => _text(full),
        ],
      });

      final result = await importerFor(adapter).importLinks([link(url, 3)]);

      expect(adapter.calls[url], 2);
      expect(households.all.map((e) => e.clientReferenceId), ['h1', 'h2', 'h3']);
      expect(result.importedCount, 3);
    });

    test('gives up after three attempts and rethrows', () async {
      const url = 'https://files.test/always-drops.ndjson';
      final adapter = _ScriptedAdapter({
        url: [() => _dropAfter('')]
      });

      await expectLater(
        importerFor(adapter).importLinks([link(url, 1)]),
        throwsA(isA<HttpException>()),
      );
      expect(adapter.calls[url], 3);
    });

    test('a malformed line is not retried', () async {
      const url = 'https://files.test/bad.ndjson';
      final adapter = _ScriptedAdapter({
        url: [() => _text('{"_t": "HOUSEHOLD", ')]
      });

      await expectLater(
        importerFor(adapter).importLinks([link(url, 1)]),
        throwsA(isA<FormatException>()),
      );
      expect(adapter.calls[url], 1);
    });

    test('reports progress with the last imported entity type', () async {
      const url = 'https://files.test/p.ndjson';
      final adapter = _ScriptedAdapter({
        url: [() => _text(_ndjson([_hh('h1'), _ind('i1')]))]
      });
      final seen = <(int, String)>[];

      await importerFor(adapter).importLinks(
        [link(url, 2)],
        onProgress: (total, _, __, linkImported, type) =>
            seen.add((linkImported, type)),
      );

      expect(seen.first, (0, ''));
      expect(seen.last, (2, 'INDIVIDUAL'));
    });

    // Kogo, 2026-10-13: the dialog showed "Household Members 0…9" while the
    // INDIVIDUALS file was starting, because the start-of-link call carried
    // the last `_t` of the previous file.
    test('the progress call that starts a link carries no type from the '
        'previous file', () async {
      const hhFile = 'https://files.test/hh_members.ndjson';
      const indFile = 'https://files.test/individuals.ndjson';
      final adapter = _ScriptedAdapter({
        hhFile: [() => _text(_ndjson([_hh('h1'), _member('m1')]))],
        indFile: [() => _text(_ndjson([_ind('i1')]))],
      });
      final seen = <(String, int, String)>[];

      await importerFor(adapter).importLinks(
        [
          link(hhFile, 2, type: 'HH_MEMBERS'),
          link(indFile, 1, type: 'INDIVIDUALS'),
        ],
        onProgress: (total, _, currentLink, linkImported, type) =>
            seen.add((currentLink.fileType, linkImported, type)),
      );

      expect(seen, [
        ('HH_MEMBERS', 0, ''),
        ('HH_MEMBERS', 2, 'HOUSEHOLD_MEMBER'),
        ('INDIVIDUALS', 0, ''),
        ('INDIVIDUALS', 1, 'INDIVIDUAL'),
      ]);
    });
  });

  // Kogo, 2026-10-13: 4 small files imported in ~4 s, one of them in 23 ms,
  // so the progress dialog flashed past unreadably.
  group('minLinkDuration', () {
    const hhFile = 'https://files.test/hh_members.ndjson';
    const indFile = 'https://files.test/individuals.ndjson';
    final t0 = DateTime(2026, 10, 13, 16, 22);

    _ScriptedAdapter twoFiles() => _ScriptedAdapter({
          hhFile: [() => _text(_ndjson([_hh('h1')]))],
          indFile: [() => _text(_ndjson([_ind('i1')]))],
        });

    List<BeneficiaryDownloadLink> twoLinks() => [
          link(hhFile, 1, type: 'HH_MEMBERS'),
          link(indFile, 1, type: 'INDIVIDUALS'),
        ];

    test('holds a fast link on screen before the next link starts', () async {
      final events = <String>[];
      final importer = importerFor(
        twoFiles(),
        minLinkDuration: const Duration(seconds: 1),
        now: () => t0,
        wait: (d) async => events.add('wait ${d.inMilliseconds}'),
      );

      await importer.importLinks(
        twoLinks(),
        onProgress: (_, __, current, linkImported, ___) =>
            events.add('${current.fileType} $linkImported'),
      );

      expect(events, [
        'HH_MEMBERS 0',
        'HH_MEMBERS 1',
        'wait 1000',
        'INDIVIDUALS 0',
        'INDIVIDUALS 1',
        'wait 1000',
      ]);
    });

    test('waits only for the part of the minimum the link has not used',
        () async {
      var clock = t0;
      final waits = <Duration>[];
      final importer = importerFor(
        twoFiles(),
        minLinkDuration: const Duration(seconds: 1),
        now: () => clock,
        wait: (d) async => waits.add(d),
      );

      await importer.importLinks(
        twoLinks(),
        onProgress: (_, __, ___, linkImported, ____) {
          // Each link takes 400 ms between its first and last progress call.
          if (linkImported > 0) {
            clock = clock.add(const Duration(milliseconds: 400));
          }
        },
      );

      expect(waits, [
        const Duration(milliseconds: 600),
        const Duration(milliseconds: 600),
      ]);
    });

    test('does not hold a link that took longer than the minimum', () async {
      var clock = t0;
      final waits = <Duration>[];
      final importer = importerFor(
        twoFiles(),
        minLinkDuration: const Duration(seconds: 1),
        now: () => clock,
        wait: (d) async => waits.add(d),
      );

      await importer.importLinks(
        twoLinks(),
        onProgress: (_, __, ___, linkImported, ____) {
          if (linkImported > 0) {
            clock = clock.add(const Duration(milliseconds: 1500));
          }
        },
      );

      expect(waits, isEmpty);
    });

    test('does not hold a link a resume skips', () async {
      final waits = <Duration>[];
      final adapter = twoFiles();
      final importer = importerFor(
        adapter,
        minLinkDuration: const Duration(seconds: 1),
        now: () => t0,
        wait: (d) async => waits.add(d),
      );

      await importer.importLinks(twoLinks(), startFromOffset: 1);

      expect(adapter.calls[hhFile], isNull);
      expect(waits, [const Duration(seconds: 1)]);
    });

    test('does not hold by default', () async {
      final waits = <Duration>[];
      final importer = importerFor(
        twoFiles(),
        now: () => t0,
        wait: (d) async => waits.add(d),
      );

      await importer.importLinks(twoLinks());

      expect(waits, isEmpty);
    });
  });

  group('parseDownloadLinks', () {
    test('keeps links with a url and a positive record count', () {
      final links = parseDownloadLinks({
        'DownloadLinks': [
          {'fileType': 'HH_MEMBERS', 'url': 'https://f/1', 'recordCount': 10},
          {'fileType': 'TASKS', 'url': 'https://f/2', 'recordCount': '4'},
          {'fileType': 'EMPTY', 'url': 'https://f/3', 'recordCount': 0},
          {'fileType': 'NOURL', 'url': '', 'recordCount': 5},
          'not-a-map',
        ],
      });

      expect(links.map((l) => l.url), ['https://f/1', 'https://f/2']);
      expect(links.map((l) => l.recordCount), [10, 4]);
    });

    test('returns no links for a paginated response or a failed call', () {
      expect(
        parseDownloadLinks({
          'DownsyncCriteria': {'totalCount': 12}
        }),
        isEmpty,
      );
      expect(parseDownloadLinks({}), isEmpty);
      expect(parseDownloadLinks({'DownloadLinks': 'oops'}), isEmpty);
    });

    test('downloadLinksRecordCount sums the record counts', () {
      expect(
        downloadLinksRecordCount([
          const BeneficiaryDownloadLink(
              fileType: 'A', url: 'u1', recordCount: 3),
          const BeneficiaryDownloadLink(
              fileType: 'B', url: 'u2', recordCount: 9),
        ]),
        12,
      );
    });
  });

  group('resolveDownsyncProjectId', () {
    test('uses the first id of the project hierarchy', () {
      expect(resolveDownsyncProjectId('root.state.lga', 'own'), 'root');
    });

    test("falls back to the project's own id when the hierarchy is empty", () {
      expect(resolveDownsyncProjectId(null, 'own'), 'own');
      expect(resolveDownsyncProjectId('', 'own'), 'own');
      expect(resolveDownsyncProjectId('  ', 'own'), 'own');
    });

    test('skips empty segments', () {
      expect(resolveDownsyncProjectId('.root.state', 'own'), 'root');
    });
  });

  group('resolveResumeOffset', () {
    test('resumes a file import that stopped part-way', () {
      expect(
        resolveResumeOffset(
            storedOffset: 1500, storedLimit: 0, storedTotalCount: 4000,
            linksTotal: 4000),
        1500,
      );
    });

    test('starts over when there is no stored row', () {
      expect(
        resolveResumeOffset(
            storedOffset: null, storedLimit: null, storedTotalCount: null,
            linksTotal: 4000),
        0,
      );
    });

    test('starts over when the server file has a different record count', () {
      expect(
        resolveResumeOffset(
            storedOffset: 1500, storedLimit: 0, storedTotalCount: 4000,
            linksTotal: 4100),
        0,
      );
    });

    test('ignores the offset of a paginated download', () {
      expect(
        resolveResumeOffset(
            storedOffset: 200, storedLimit: 50, storedTotalCount: 4000,
            linksTotal: 4000),
        0,
      );
    });

    test('starts over after a completed import', () {
      expect(
        resolveResumeOffset(
            storedOffset: 0, storedLimit: 0, storedTotalCount: 4000,
            linksTotal: 4000),
        0,
      );
      expect(
        resolveResumeOffset(
            storedOffset: 4000, storedLimit: 0, storedTotalCount: 4000,
            linksTotal: 4000),
        0,
      );
    });
  });

  group('downsyncEntityLabel', () {
    test('names known entity types and is blank for anything else', () {
      expect(downsyncEntityLabel('HOUSEHOLD'), 'Households');
      expect(downsyncEntityLabel('PROJECT_TASK'), 'Tasks');
      expect(downsyncEntityLabel('USER_ACTION'), '');
      expect(downsyncEntityLabel(''), '');
    });

    test('names the file types the server sends', () {
      expect(downsyncEntityLabel('HH_MEMBERS'), 'Households & Members');
      expect(downsyncEntityLabel('INDIVIDUALS'), 'Individuals');
      expect(downsyncEntityLabel('BENE_AE_REF'), 'Beneficiaries');
      expect(downsyncEntityLabel('TASKS'), 'Tasks');
    });
  });

  group('progressEntityType', () {
    BeneficiaryDownloadLink file(String type) =>
        BeneficiaryDownloadLink(fileType: type, url: 'u', recordCount: 15);

    // The bar counts lines of the whole file (HH_MEMBERS = households +
    // members), so a known file type names it, not the last line's `_t`.
    test('a known file type wins over the last line type', () {
      expect(progressEntityType(file('HH_MEMBERS'), 'HOUSEHOLD_MEMBER'),
          'HH_MEMBERS');
    });

    test('an unknown file type falls back to the last line type', () {
      expect(progressEntityType(file('NEW_FILE'), 'INDIVIDUAL'), 'INDIVIDUAL');
      expect(progressEntityType(file(''), 'INDIVIDUAL'), 'INDIVIDUAL');
    });

    test('is blank when neither has a label', () {
      expect(progressEntityType(file('NEW_FILE'), ''), '');
      expect(progressEntityType(file(''), ''), '');
    });
  });
}
