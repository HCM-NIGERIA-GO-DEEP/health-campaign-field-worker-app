// T13 - the Beneficiary IDs page's Download button. Until the local count has
// loaded the page showed 0 with Download enabled, inviting a download of IDs
// the worker already had (QA, 2026-10-30: 0 shown with 599 on the device).
import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/utils/beneficiary_id_download_gate.dart';

void main() {
  test('T13: count not loaded yet -> disabled, even though it reads 0', () {
    expect(
        isBeneficiaryIdDownloadDisabled(
            countLoaded: false, available: 0, minCount: 10),
        isTrue);
  });

  test('T13: loaded with more than the minimum -> disabled', () {
    expect(
        isBeneficiaryIdDownloadDisabled(
            countLoaded: true, available: 599, minCount: 10),
        isTrue);
  });

  test('T13: loaded at or below the minimum -> enabled', () {
    expect(
        isBeneficiaryIdDownloadDisabled(
            countLoaded: true, available: 10, minCount: 10),
        isFalse);
    expect(
        isBeneficiaryIdDownloadDisabled(
            countLoaded: true, available: 0, minCount: 10),
        isFalse);
  });
}
