/// Whether the app root (`MaterialApp` in app.dart) must rebuild for a new
/// `LocalizationState`.
///
/// Rebuild when the language changes, and when a text load has ended (done or
/// failed): that rebuild reloads every package's text list with the texts that
/// were just loaded, including the boundary names. Skip the state that only
/// says "a load has started": rebuilding then re-reads the old texts and
/// rebuilds every screen for nothing.
///
/// Kept free of app imports so its tests compile on their own.
bool shouldRebuildAppForLocalization({
  required int previousIndex,
  required int currentIndex,
  required bool currentLoading,
}) {
  return currentIndex != previousIndex || !currentLoading;
}
