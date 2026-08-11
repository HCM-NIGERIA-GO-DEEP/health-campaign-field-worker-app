// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_event.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAnalyticsEventCollection on Isar {
  IsarCollection<AnalyticsEvent> get analyticsEvents => this.collection();
}

const AnalyticsEventSchema = CollectionSchema(
  name: r'AnalyticsEvent',
  id: 9135082011256516380,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'name': PropertySchema(
      id: 1,
      name: r'name',
      type: IsarType.string,
    ),
    r'nonRecoverableError': PropertySchema(
      id: 2,
      name: r'nonRecoverableError',
      type: IsarType.bool,
    ),
    r'occurredAt': PropertySchema(
      id: 3,
      name: r'occurredAt',
      type: IsarType.dateTime,
    ),
    r'paramsJson': PropertySchema(
      id: 4,
      name: r'paramsJson',
      type: IsarType.string,
    ),
    r'retryCount': PropertySchema(
      id: 5,
      name: r'retryCount',
      type: IsarType.long,
    ),
    r'syncedUp': PropertySchema(
      id: 6,
      name: r'syncedUp',
      type: IsarType.bool,
    ),
    r'syncedUpOn': PropertySchema(
      id: 7,
      name: r'syncedUpOn',
      type: IsarType.dateTime,
    ),
    r'userId': PropertySchema(
      id: 8,
      name: r'userId',
      type: IsarType.string,
    )
  },
  estimateSize: _analyticsEventEstimateSize,
  serialize: _analyticsEventSerialize,
  deserialize: _analyticsEventDeserialize,
  deserializeProp: _analyticsEventDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _analyticsEventGetId,
  getLinks: _analyticsEventGetLinks,
  attach: _analyticsEventAttach,
  version: '3.1.0+1',
);

int _analyticsEventEstimateSize(
  AnalyticsEvent object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.paramsJson.length * 3;
  {
    final value = object.userId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _analyticsEventSerialize(
  AnalyticsEvent object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.name);
  writer.writeBool(offsets[2], object.nonRecoverableError);
  writer.writeDateTime(offsets[3], object.occurredAt);
  writer.writeString(offsets[4], object.paramsJson);
  writer.writeLong(offsets[5], object.retryCount);
  writer.writeBool(offsets[6], object.syncedUp);
  writer.writeDateTime(offsets[7], object.syncedUpOn);
  writer.writeString(offsets[8], object.userId);
}

AnalyticsEvent _analyticsEventDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AnalyticsEvent();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.name = reader.readString(offsets[1]);
  object.nonRecoverableError = reader.readBool(offsets[2]);
  object.occurredAt = reader.readDateTime(offsets[3]);
  object.paramsJson = reader.readString(offsets[4]);
  object.retryCount = reader.readLong(offsets[5]);
  object.syncedUp = reader.readBool(offsets[6]);
  object.syncedUpOn = reader.readDateTimeOrNull(offsets[7]);
  object.userId = reader.readStringOrNull(offsets[8]);
  return object;
}

P _analyticsEventDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _analyticsEventGetId(AnalyticsEvent object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _analyticsEventGetLinks(AnalyticsEvent object) {
  return [];
}

void _analyticsEventAttach(
    IsarCollection<dynamic> col, Id id, AnalyticsEvent object) {
  object.id = id;
}

extension AnalyticsEventQueryWhereSort
    on QueryBuilder<AnalyticsEvent, AnalyticsEvent, QWhere> {
  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AnalyticsEventQueryWhere
    on QueryBuilder<AnalyticsEvent, AnalyticsEvent, QWhereClause> {
  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterWhereClause> idBetween(
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

extension AnalyticsEventQueryFilter
    on QueryBuilder<AnalyticsEvent, AnalyticsEvent, QFilterCondition> {
  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
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

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
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

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition> idBetween(
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

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      nonRecoverableErrorEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nonRecoverableError',
        value: value,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      occurredAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'occurredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      occurredAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'occurredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      occurredAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'occurredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      occurredAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'occurredAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      paramsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'paramsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      paramsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'paramsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      paramsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'paramsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      paramsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'paramsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      paramsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'paramsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      paramsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'paramsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      paramsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'paramsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      paramsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'paramsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      paramsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'paramsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      paramsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'paramsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      retryCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retryCount',
        value: value,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      retryCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'retryCount',
        value: value,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      retryCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'retryCount',
        value: value,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      retryCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'retryCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      syncedUpEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncedUp',
        value: value,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      syncedUpOnIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'syncedUpOn',
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      syncedUpOnIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'syncedUpOn',
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      syncedUpOnEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncedUpOn',
        value: value,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      syncedUpOnGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'syncedUpOn',
        value: value,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      syncedUpOnLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'syncedUpOn',
        value: value,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      syncedUpOnBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'syncedUpOn',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      userIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'userId',
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      userIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'userId',
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      userIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      userIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      userIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      userIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'userId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      userIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      userIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      userIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      userIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'userId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      userIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userId',
        value: '',
      ));
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterFilterCondition>
      userIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'userId',
        value: '',
      ));
    });
  }
}

extension AnalyticsEventQueryObject
    on QueryBuilder<AnalyticsEvent, AnalyticsEvent, QFilterCondition> {}

extension AnalyticsEventQueryLinks
    on QueryBuilder<AnalyticsEvent, AnalyticsEvent, QFilterCondition> {}

extension AnalyticsEventQuerySortBy
    on QueryBuilder<AnalyticsEvent, AnalyticsEvent, QSortBy> {
  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      sortByNonRecoverableError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nonRecoverableError', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      sortByNonRecoverableErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nonRecoverableError', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      sortByOccurredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'occurredAt', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      sortByOccurredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'occurredAt', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      sortByParamsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paramsJson', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      sortByParamsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paramsJson', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      sortByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      sortByRetryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy> sortBySyncedUp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncedUp', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      sortBySyncedUpDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncedUp', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      sortBySyncedUpOn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncedUpOn', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      sortBySyncedUpOnDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncedUpOn', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy> sortByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      sortByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension AnalyticsEventQuerySortThenBy
    on QueryBuilder<AnalyticsEvent, AnalyticsEvent, QSortThenBy> {
  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      thenByNonRecoverableError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nonRecoverableError', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      thenByNonRecoverableErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nonRecoverableError', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      thenByOccurredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'occurredAt', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      thenByOccurredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'occurredAt', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      thenByParamsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paramsJson', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      thenByParamsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'paramsJson', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      thenByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      thenByRetryCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retryCount', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy> thenBySyncedUp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncedUp', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      thenBySyncedUpDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncedUp', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      thenBySyncedUpOn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncedUpOn', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      thenBySyncedUpOnDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncedUpOn', Sort.desc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy> thenByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QAfterSortBy>
      thenByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension AnalyticsEventQueryWhereDistinct
    on QueryBuilder<AnalyticsEvent, AnalyticsEvent, QDistinct> {
  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QDistinct>
      distinctByNonRecoverableError() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nonRecoverableError');
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QDistinct>
      distinctByOccurredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'occurredAt');
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QDistinct> distinctByParamsJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'paramsJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QDistinct>
      distinctByRetryCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retryCount');
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QDistinct> distinctBySyncedUp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncedUp');
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QDistinct>
      distinctBySyncedUpOn() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncedUpOn');
    });
  }

  QueryBuilder<AnalyticsEvent, AnalyticsEvent, QDistinct> distinctByUserId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userId', caseSensitive: caseSensitive);
    });
  }
}

extension AnalyticsEventQueryProperty
    on QueryBuilder<AnalyticsEvent, AnalyticsEvent, QQueryProperty> {
  QueryBuilder<AnalyticsEvent, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AnalyticsEvent, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<AnalyticsEvent, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<AnalyticsEvent, bool, QQueryOperations>
      nonRecoverableErrorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nonRecoverableError');
    });
  }

  QueryBuilder<AnalyticsEvent, DateTime, QQueryOperations>
      occurredAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'occurredAt');
    });
  }

  QueryBuilder<AnalyticsEvent, String, QQueryOperations> paramsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'paramsJson');
    });
  }

  QueryBuilder<AnalyticsEvent, int, QQueryOperations> retryCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retryCount');
    });
  }

  QueryBuilder<AnalyticsEvent, bool, QQueryOperations> syncedUpProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncedUp');
    });
  }

  QueryBuilder<AnalyticsEvent, DateTime?, QQueryOperations>
      syncedUpOnProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncedUpOn');
    });
  }

  QueryBuilder<AnalyticsEvent, String?, QQueryOperations> userIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userId');
    });
  }
}
