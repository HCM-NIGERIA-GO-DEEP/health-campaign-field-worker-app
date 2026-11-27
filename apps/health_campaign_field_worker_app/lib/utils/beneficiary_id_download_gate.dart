/// Whether the Beneficiary IDs page disables its Download button.
///
/// The local count is read after the page opens. Until it arrives the page
/// used to read 0, so a worker holding enough IDs could start a download they
/// did not need; the button now stays disabled until the count is known.
bool isBeneficiaryIdDownloadDisabled({
  required bool countLoaded,
  required int available,
  required int minCount,
}) {
  if (!countLoaded) return true;
  return available > minCount;
}
