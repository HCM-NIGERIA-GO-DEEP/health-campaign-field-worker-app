import 'dart:math';

/// Given names common in northern Nigeria, where the campaign runs.
///
/// Deliberately includes clusters that stress the matcher: Mohammed/Muhammad/
/// Muhammed sound alike, and Hassan/Husseini share a prefix.
const givenNames = <String>[
  'Musa', 'Ibrahim', 'Aliyu', 'Abubakar', 'Sani', 'Yusuf', 'Umar', 'Bello',
  'Hassan', 'Husseini', 'Ahmed', 'Mohammed', 'Muhammad', 'Suleiman', 'Adamu',
  'Danjuma', 'Emmanuel', 'John', 'Peter', 'Samuel', 'Joseph', 'Solomon',
  'Istifanus', 'Yakubu', 'Zakari', 'Haruna', 'Idris', 'Nuhu', 'Saidu', 'Tanko',
  'Audu', 'Garba', 'Lawal', 'Shehu', 'Kabiru', 'Nasiru', 'Rabiu', 'Bitrus',
  'Aisha', 'Fatima', 'Zainab', 'Hauwa', 'Maryam', 'Halima', 'Amina', 'Safiya',
  'Rukayya', 'Hadiza', 'Grace', 'Mary', 'Esther', 'Blessing', 'Ruth',
  'Rebecca', 'Comfort', 'Patience', 'Naomi', 'Talatu', 'Ladi', 'Asabe',
];

/// Family names common in the same region.
const familyNames = <String>[
  'Ibrahim', 'Mohammed', 'Musa', 'Bello', 'Danjuma', 'Yakubu', 'Adamu', 'Sule',
  'Garba', 'Haruna', 'Abubakar', 'Usman', 'Aliyu', 'Sani', 'Lawal', 'Bakari',
  'Nuhu', 'Zakari', 'Jauro', 'Manu', 'Buba', 'Wakili', 'Tukur', 'Ardo',
  'Hamman', 'Njobdi', 'Dauda', 'Yusufu', 'Iliya', 'Bitrus', 'Ishaya',
  'Filibus', 'Amos', 'Barnabas', 'Gambo', 'Maigari', 'Tijjani', 'Abdullahi',
];

/// One generated beneficiary, in the shape `DedupEngine` scores.
Map<String, dynamic> beneficiary({
  required String id,
  required String givenName,
  required String familyName,
}) =>
    {
      'id': id,
      'givenName': givenName,
      'familyName': familyName,
    };

/// A probe paired with the corpus id it is meant to find, or null when it
/// should find nothing.
class PlantedCase {
  final String label;
  final Map<String, dynamic> probe;

  /// Corpus id the probe should match, or null if it must not match anything.
  final String? expectedId;

  const PlantedCase(this.label, this.probe, this.expectedId);
}

/// A deterministic corpus of [size] beneficiaries plus a set of probes with
/// known right answers.
///
/// Seeded so a failure is reproducible: the same run always produces the same
/// names in the same order.
class TestCorpus {
  final List<Map<String, dynamic>> records;
  final List<PlantedCase> cases;

  const TestCorpus(this.records, this.cases);

  static TestCorpus generate({int size = 1000, int seed = 20260909}) {
    final random = Random(seed);
    final records = <Map<String, dynamic>>[];

    for (var i = 0; i < size; i++) {
      records.add(beneficiary(
        id: 'B${i.toString().padLeft(4, '0')}',
        givenName: givenNames[random.nextInt(givenNames.length)],
        familyName: familyNames[random.nextInt(familyNames.length)],
      ));
    }

    // Plant known people at fixed ids so the probes below have exact answers.
    // Their names are absent from the lists above, so nothing else collides.
    const planted = <String, List<String>>{
      'P-EXACT': ['Yohanna', 'Kwaghbula'],
      'P-TYPO': ['Zebedee', 'Mshelbwala'],
      'P-PHONETIC': ['Kachalla', 'Gwamna'],
      'P-DIACRITIC': ['Ngozika', 'Chukwuemeka'],
      'P-AFFIX': ['Almustapha', 'Elyakubu'],
    };
    planted.forEach((id, name) {
      records.add(beneficiary(id: id, givenName: name[0], familyName: name[1]));
    });

    final cases = <PlantedCase>[
      PlantedCase(
        'exact duplicate',
        beneficiary(id: 'probe', givenName: 'Yohanna', familyName: 'Kwaghbula'),
        'P-EXACT',
      ),
      PlantedCase(
        'single-letter typo in the given name',
        beneficiary(
            id: 'probe', givenName: 'Zebedee', familyName: 'Mshelbwala'),
        'P-TYPO',
      ),
      PlantedCase(
        'transposed letters in the family name',
        beneficiary(
            id: 'probe', givenName: 'Zebedee', familyName: 'Mshelbwlaa'),
        'P-TYPO',
      ),
      PlantedCase(
        'doubled letter',
        beneficiary(id: 'probe', givenName: 'Kachallaa', familyName: 'Gwamna'),
        'P-PHONETIC',
      ),
      PlantedCase(
        'accented spelling of the same name',
        beneficiary(
            id: 'probe', givenName: 'Ngózíka', familyName: 'Chukwuemeka'),
        'P-DIACRITIC',
      ),
      PlantedCase(
        'affixed spelling of the same name',
        beneficiary(
            id: 'probe', givenName: 'Al-Mustapha', familyName: 'El-Yakubu'),
        'P-AFFIX',
      ),
      PlantedCase(
        'nobody by that name',
        beneficiary(
            id: 'probe', givenName: 'Xiulan', familyName: 'Vandermeer'),
        null,
      ),
    ];

    return TestCorpus(records, cases);
  }

  /// Index of the record carrying [id].
  int indexOf(String id) => records.indexWhere((r) => r['id'] == id);
}
