import 'package:bloc_test/bloc_test.dart';
import 'package:digit_data_model/blocs/boundary/boundary.dart';
import 'package:digit_data_model/models/entities/boundary.dart';
import 'package:digit_data_model/utils/typedefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBoundaryDataRepository extends Mock
    implements BoundaryDataRepository {}

class FakeBoundarySearchModel extends Fake implements BoundarySearchModel {}

void main() {
  // Registering fallback value for the search model.
  setUpAll(() {
    registerFallbackValue(FakeBoundarySearchModel());
  });

  late MockBoundaryDataRepository mockBoundaryDataRepository;
  late BoundaryBloc boundaryBloc;

  // Initializing mock objects before each test.
  setUp(() {
    mockBoundaryDataRepository = MockBoundaryDataRepository();
    boundaryBloc = BoundaryBloc(
      const BoundaryState(),
      boundaryRepository: mockBoundaryDataRepository,
    );
  });

  group('BoundaryBloc', () {
    // Testing the initial state.
    test('initial state is BoundaryState', () {
      expect(boundaryBloc.state, equals(const BoundaryState()));
    });

    test('an active community takes precedence over the last selection',
        () async {
      final communities = List.generate(
        4,
        (index) => BoundaryModel(code: 'COM_$index', label: 'Community'),
      );
      final bloc = BoundaryBloc(
        BoundaryState(
          selectedLastLevelBoundaries: communities,
          allSelectedLastLevelBoundaries: communities,
        ),
        boundaryRepository: mockBoundaryDataRepository,
      );
      addTearDown(bloc.close);

      final changes = <BoundaryModel?>[];
      bloc.activeBoundary.addListener(
        () => changes.add(bloc.activeBoundary.value),
      );
      bloc.setActiveBoundary(communities[2]);

      expect(bloc.currentBoundary, communities[2]);
      expect(changes, [communities[2]]);
      expect(bloc.state.effectiveSelectedBoundaries, communities);
    });

    // Mock data for testing.
    final testBoundaries = [
      BoundaryModel(name: 'Bangalore', code: 'BAN001'),
    ];

    test('loads distribution points and uses their communities for sync',
        () async {
      final facility = BoundaryModel(
        code: 'HF',
        label: 'Health Facility',
        boundaryNum: 1,
        materializedPath: 'HF',
      );
      final point = BoundaryModel(
        code: 'DP',
        label: 'Distribution Point',
        boundaryNum: 2,
        materializedPath: 'HF.DP',
      );
      final community = BoundaryModel(
        code: 'COM',
        label: 'Community',
        boundaryNum: 3,
        materializedPath: 'HF.DP.COM',
      );

      when(() => mockBoundaryDataRepository.search(any())).thenAnswer(
        (invocation) async {
          final query =
              invocation.positionalArguments.single as BoundarySearchModel;
          if (query.isSingle == true) return [facility];
          if (query.codes == 'HF') return [point];
          return [community];
        },
      );

      final loaded = boundaryBloc.stream.first;
      boundaryBloc.add(const BoundaryEvent.findBoundary(code: 'HF'));
      expect((await loaded).boundaryList, [facility, point]);

      final selected = boundaryBloc.stream.firstWhere(
        (state) =>
            !state.loading &&
            state.selectedBoundaryMap[point.label] == point &&
            state.boundaryList.contains(community),
      );
      boundaryBloc
        ..add(const BoundaryEvent.search(code: 'DP', boundaryNum: 2))
        ..add(
            BoundaryEvent.select(label: point.label!, selectedBoundary: point));
      expect((await selected).effectiveSelectedBoundaries, [community]);
      await boundaryBloc.close();
    });

    // Test case for successfully loading boundaries.
    blocTest<BoundaryBloc, BoundaryState>(
      'emits [BoundaryState with loading true, BoundaryState with empty boundaries] when BoundarySearchEvent results in no match',
      build: () {
        when(() => mockBoundaryDataRepository.search(any()))
            .thenAnswer((invocation) async {
          final searchModel =
              invocation.positionalArguments[0] as BoundarySearchModel;
          if (searchModel.codes == testBoundaries.first.code) {
            return testBoundaries;
          } else {
            return [];
          }
        });
        return boundaryBloc;
      },
      act: (bloc) =>
          bloc.add(const BoundaryEvent.search(code: 'BAN001', boundaryNum: 1)),
      expect: () => [
        const BoundaryState(loading: true),
        BoundaryState(boundaryList: testBoundaries, loading: false),
      ],
      verify: (_) {
        verify(() => mockBoundaryDataRepository.search(any())).called(1);
      },
    );

    // Test case for empty boundaries result.
    blocTest<BoundaryBloc, BoundaryState>(
      'emits [BoundaryState with loading true, BoundaryState with empty boundaries] when BoundarySearchEvent results in empty boundaries',
      build: () {
        when(() => mockBoundaryDataRepository.search(any()))
            .thenAnswer((_) async => []);
        return boundaryBloc;
      },
      act: (bloc) =>
          bloc.add(const BoundaryEvent.search(code: 'BAN001', boundaryNum: 1)),
      expect: () => [
        const BoundaryState(loading: true),
        const BoundaryState(boundaryList: [], loading: false),
      ],
      verify: (_) {
        verify(() => mockBoundaryDataRepository.search(any())).called(1);
      },
    );
  });
}
