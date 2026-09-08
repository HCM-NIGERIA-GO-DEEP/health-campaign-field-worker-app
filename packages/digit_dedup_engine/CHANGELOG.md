## 0.0.1-dev

* Initial package structure.
* Implemented Soundex, Jaro-Winkler and Levenshtein, name normalization and
  affix removal, phonetic blocking, and multi-attribute weighted scoring with
  weight renormalization over the attributes two records share.
* Added `DedupEngine.findMatchesFor`, which scores one incoming record against
  a corpus of existing records, plus the `DedupMatch` model it returns.
* `DoubleMetaphone.encode` is still unimplemented; nothing in the package calls
  it.
