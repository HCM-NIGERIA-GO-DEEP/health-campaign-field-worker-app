import 'dart:async';

import 'package:digit_flow_builder/blocs/app_localization.dart';
import 'package:digit_forms_engine/blocs/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Row {
  const _Row(this.code, this.message);
  final String code;
  final String message;
  String get locale => 'en_LR';
}

/// The flow builder and the forms engine reload their texts on every
/// MaterialApp rebuild. Each cleared its copy BEFORE reading the new rows, so
/// while the read was running every text came back as its raw key, and a
/// screen built in that window showed keys.
void main() {
  const locale = Locale('en', 'LR');

  test('flow builder: the old texts stay until the new ones are read',
      () async {
    await FlowBuilderLocalization(
      locale,
      Future.value(const [_Row('HEADING', 'Close household')]),
      const [],
    ).load();
    final read = Completer<List<_Row>>();
    final reload =
        FlowBuilderLocalization(locale, read.future, const []).load();
    await Future<void>.delayed(Duration.zero);

    final texts = FlowBuilderLocalization(locale, Future.value(const []), const []);
    expect(texts.translate('HEADING'), 'Close household',
        reason: 'the read has not finished yet');

    read.complete(const [_Row('HEADING', 'Closed household')]);
    await reload;
    expect(texts.translate('HEADING'), 'Closed household');
  });

  test('forms engine: the old texts stay until the new ones are read',
      () async {
    await FormLocalization(
      locale,
      Future.value(const [_Row('REASON', 'Reason')]),
      const [],
    ).load();
    final read = Completer<List<_Row>>();
    final reload = FormLocalization(locale, read.future, const []).load();
    await Future<void>.delayed(Duration.zero);

    final texts = FormLocalization(locale, Future.value(const []), const []);
    expect(texts.translate('REASON'), 'Reason',
        reason: 'the read has not finished yet');

    read.complete(const [_Row('REASON', 'Why')]);
    await reload;
    expect(texts.translate('REASON'), 'Why');
  });

  test('a reload drops texts that are no longer stored', () async {
    await FlowBuilderLocalization(
      locale,
      Future.value(const [_Row('OLD', 'Old text')]),
      const [],
    ).load();
    await FlowBuilderLocalization(
      locale,
      Future.value(const [_Row('NEW', 'New text')]),
      const [],
    ).load();

    final texts = FlowBuilderLocalization(locale, Future.value(const []), const []);
    expect(texts.translate('OLD'), 'OLD');
    expect(texts.translate('NEW'), 'New text');
  });
}
