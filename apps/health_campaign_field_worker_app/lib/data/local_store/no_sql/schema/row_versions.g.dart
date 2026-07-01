// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'row_versions.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetRowVersionListCollection on Isar {
  IsarCollection<RowVersionList> get rowVersionLists => this.collection();
}

const RowVersionListSchema = CollectionSchema(
  name: r'RowVersionList',
  id: 7716197199845281802,
  properties: {
    r'module': PropertySchema(
      id: 0,
      name: r'module',
      type: IsarType.string,
    ),
    r'uniqueBeneficiaryIdLimit': PropertySchema(
      id: 1,
      name: r'uniqueBeneficiaryIdLimit',
      type: IsarType.long,
    ),
    r'uniquenumbercount': PropertySchema(
      id: 2,
      name: r'uniquenumbercount',
      type: IsarType.long,
    ),
    r'uniquenumbertype': PropertySchema(
      id: 3,
      name: r'uniquenumbertype',
      type: IsarType.string,
    ),
    r'version': PropertySchema(
      id: 4,
      name: r'version',
      type: IsarType.string,
    )
  },
  estimateSize: _rowVersionListEstimateSize,
  serialize: _rowVersionListSerialize,
  deserialize: _rowVersionListDeserialize,
  deserializeProp: _rowVersionListDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _rowVersionListGetId,
  getLinks: _rowVersionListGetLinks,
  attach: _rowVersionListAttach,
  version: '3.1.0+1',
);

int _rowVersionListEstimateSize(
  RowVersionList object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.module.length * 3;
  {
    final value = object.uniquenumbertype;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.version.length * 3;
  return bytesCount;
}

void _rowVersionListSerialize(
  RowVersionList object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.module);
  writer.writeLong(offsets[1], object.uniqueBeneficiaryIdLimit);
  writer.writeLong(offsets[2], object.uniquenumbercount);
  writer.writeString(offsets[3], object.uniquenumbertype);
  writer.writeString(offsets[4], object.version);
}

RowVersionList _rowVersionListDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = RowVersionList();
  object.id = id;
  object.module = reader.readString(offsets[0]);
  object.uniqueBeneficiaryIdLimit = reader.readLongOrNull(offsets[1]);
  object.uniquenumbercount = reader.readLongOrNull(offsets[2]);
  object.uniquenumbertype = reader.readStringOrNull(offsets[3]);
  object.version = reader.readString(offsets[4]);
  return object;
}

P _rowVersionListDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _rowVersionListGetId(RowVersionList object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _rowVersionListGetLinks(RowVersionList object) {
  return [];
}

void _rowVersionListAttach(
    IsarCollection<dynamic> col, Id id, RowVersionList object) {
  object.id = id;
}

extension RowVersionListQueryWhereSort
    on QueryBuilder<RowVersionList, RowVersionList, QWhere> {
  QueryBuilder<RowVersionList, RowVersionList, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension RowVersionListQueryWhere
    on QueryBuilder<RowVersionList, RowVersionList, QWhereClause> {
  QueryBuilder<RowVersionList, RowVersionList, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension RowVersionListQueryFilter
    on QueryBuilder<RowVersionList, RowVersionList, QFilterCondition> {
  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      moduleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'module',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      moduleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'module',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      moduleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'module',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      moduleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'module',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      moduleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'module',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      moduleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'module',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      moduleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'module',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      moduleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'module',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      moduleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'module',
        value: '',
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      moduleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'module',
        value: '',
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniqueBeneficiaryIdLimitIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'uniqueBeneficiaryIdLimit',
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniqueBeneficiaryIdLimitIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'uniqueBeneficiaryIdLimit',
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniqueBeneficiaryIdLimitEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uniqueBeneficiaryIdLimit',
        value: value,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniqueBeneficiaryIdLimitGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'uniqueBeneficiaryIdLimit',
        value: value,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniqueBeneficiaryIdLimitLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'uniqueBeneficiaryIdLimit',
        value: value,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniqueBeneficiaryIdLimitBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'uniqueBeneficiaryIdLimit',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbercountIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'uniquenumbercount',
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbercountIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'uniquenumbercount',
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbercountEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uniquenumbercount',
        value: value,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbercountGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'uniquenumbercount',
        value: value,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbercountLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'uniquenumbercount',
        value: value,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbercountBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'uniquenumbercount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbertypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'uniquenumbertype',
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbertypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'uniquenumbertype',
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbertypeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uniquenumbertype',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbertypeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'uniquenumbertype',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbertypeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'uniquenumbertype',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbertypeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'uniquenumbertype',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbertypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'uniquenumbertype',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbertypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'uniquenumbertype',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbertypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'uniquenumbertype',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbertypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'uniquenumbertype',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbertypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uniquenumbertype',
        value: '',
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      uniquenumbertypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'uniquenumbertype',
        value: '',
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      versionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      versionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      versionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      versionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'version',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      versionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      versionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      versionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'version',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      versionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'version',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      versionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'version',
        value: '',
      ));
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterFilterCondition>
      versionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'version',
        value: '',
      ));
    });
  }
}

extension RowVersionListQueryObject
    on QueryBuilder<RowVersionList, RowVersionList, QFilterCondition> {}

extension RowVersionListQueryLinks
    on QueryBuilder<RowVersionList, RowVersionList, QFilterCondition> {}

extension RowVersionListQuerySortBy
    on QueryBuilder<RowVersionList, RowVersionList, QSortBy> {
  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy> sortByModule() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'module', Sort.asc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      sortByModuleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'module', Sort.desc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      sortByUniqueBeneficiaryIdLimit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniqueBeneficiaryIdLimit', Sort.asc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      sortByUniqueBeneficiaryIdLimitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniqueBeneficiaryIdLimit', Sort.desc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      sortByUniquenumbercount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniquenumbercount', Sort.asc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      sortByUniquenumbercountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniquenumbercount', Sort.desc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      sortByUniquenumbertype() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniquenumbertype', Sort.asc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      sortByUniquenumbertypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniquenumbertype', Sort.desc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy> sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension RowVersionListQuerySortThenBy
    on QueryBuilder<RowVersionList, RowVersionList, QSortThenBy> {
  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy> thenByModule() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'module', Sort.asc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      thenByModuleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'module', Sort.desc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      thenByUniqueBeneficiaryIdLimit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniqueBeneficiaryIdLimit', Sort.asc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      thenByUniqueBeneficiaryIdLimitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniqueBeneficiaryIdLimit', Sort.desc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      thenByUniquenumbercount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniquenumbercount', Sort.asc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      thenByUniquenumbercountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniquenumbercount', Sort.desc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      thenByUniquenumbertype() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniquenumbertype', Sort.asc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      thenByUniquenumbertypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uniquenumbertype', Sort.desc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy> thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QAfterSortBy>
      thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension RowVersionListQueryWhereDistinct
    on QueryBuilder<RowVersionList, RowVersionList, QDistinct> {
  QueryBuilder<RowVersionList, RowVersionList, QDistinct> distinctByModule(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'module', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QDistinct>
      distinctByUniqueBeneficiaryIdLimit() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uniqueBeneficiaryIdLimit');
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QDistinct>
      distinctByUniquenumbercount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uniquenumbercount');
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QDistinct>
      distinctByUniquenumbertype({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uniquenumbertype',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<RowVersionList, RowVersionList, QDistinct> distinctByVersion(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version', caseSensitive: caseSensitive);
    });
  }
}

extension RowVersionListQueryProperty
    on QueryBuilder<RowVersionList, RowVersionList, QQueryProperty> {
  QueryBuilder<RowVersionList, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<RowVersionList, String, QQueryOperations> moduleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'module');
    });
  }

  QueryBuilder<RowVersionList, int?, QQueryOperations>
      uniqueBeneficiaryIdLimitProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uniqueBeneficiaryIdLimit');
    });
  }

  QueryBuilder<RowVersionList, int?, QQueryOperations>
      uniquenumbercountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uniquenumbercount');
    });
  }

  QueryBuilder<RowVersionList, String?, QQueryOperations>
      uniquenumbertypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uniquenumbertype');
    });
  }

  QueryBuilder<RowVersionList, String, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}
