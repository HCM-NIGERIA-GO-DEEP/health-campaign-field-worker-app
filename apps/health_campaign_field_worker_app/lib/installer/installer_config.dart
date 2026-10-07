/// Set to `'owner/repo'` to point the showcase at a real GitHub Releases
/// feed. Leave blank to fall back to the bundled local demo server
/// (see `demo_server.dart`).
const String githubReleaseHost = 'egov-skb/hcm-app-installer-demo';

/// Optional bearer token, only needed for a private repo's releases.
const String githubToken = '';

bool get isGithubReleaseHostConfigured => githubReleaseHost.isNotEmpty;

/// Stable URL that always resolves to the manifest asset on the most
/// recent non-draft, non-prerelease GitHub Release.
Uri get githubManifestUrl => Uri.parse(
    'https://github.com/$githubReleaseHost/releases/latest/download/manifest.json');

/// Lists every release (not just the latest) via the GitHub REST API —
/// used by the "All releases" screen. No auth needed for a public repo.
Uri get githubReleasesApiUrl =>
    Uri.parse('https://api.github.com/repos/$githubReleaseHost/releases');
