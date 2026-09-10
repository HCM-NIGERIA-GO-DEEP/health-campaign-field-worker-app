## 0.0.1-dev

* Initial package structure.
* Implemented Soundex, Jaro-Winkler and Levenshtein, name normalization and
  affix removal, phonetic blocking, and multi-attribute weighted scoring with
  weight renormalization over the attributes two records share.
* Added `DedupEngine.findMatchesFor`, which scores one incoming record against
  a corpus of existing records, plus the `DedupMatch` model it returns.
* Implemented `DoubleMetaphone.encode`, returning a primary and an alternate
  code. Validated behaviourally rather than byte-identically against Philips'
  reference -- see README. Nothing in the package calls it yet.
* Added `DedupIndex` plus `DedupEngine.buildIndex` and `findMatchesUsing`, so
  the block index can be built once and reused instead of rebuilt per probe
  (~80% of a probe's cost at 200k candidates).
* Added a `mobileNumber` attribute, compared on the trailing nine digits and
  skipped when absent on either side. Weights renormalize over present
  attributes, so this does not change the score of any pair without a number.
* Fixed `removeAffixes` making matching *worse* for separator variants:
  "Al-Mustapha" vs "Almustapha" scored 0.767 where the un-normalized pair
  scored 0.976, because only the hyphenated spelling was stripped. Names are
  now compared through both a separator-free and an affix-stripped form, and
  block keys cover both, so a spelling variation can only ever help.
