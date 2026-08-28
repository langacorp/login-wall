/// Is this URL allowed to open inside our own WebView?
///
/// The comparison is on the SUFFIX, never `contains`: `contains` would accept
/// `example.com.someoneelse.net`, which is exactly the shape used to carry a
/// user's session onto somebody else's server.
///
/// The check is repeated at three points in the host app (reading the list,
/// opening the WebView, internal navigation) because a single point is a point
/// that somebody eventually works around without noticing.
///
/// No domain is hardcoded here. The caller supplies apex and suffix.
class DomainGuard {
  /// The bare domain, without a leading dot: `example.com`.
  final String apex;

  /// The suffix WITH the leading dot: `.example.com`.
  /// Derived from [apex] unless given explicitly.
  final String suffix;

  /// Schemes accepted. Defaults to https only: an http page inside a WebView
  /// that carries a session is a downgrade, not a convenience.
  final Set<String> allowedSchemes;

  DomainGuard({
    required this.apex,
    String? suffix,
    Set<String>? allowedSchemes,
  })  : suffix = suffix ?? '.$apex',
        allowedSchemes = allowedSchemes ?? const {'https'};

  bool isAllowed(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return false;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;
    if (!allowedSchemes.contains(uri.scheme)) return false;

    // `https://example.com@elsewhere.net/` — the host is elsewhere.net.
    // Some parsers and most humans read the part before the @ as the host.
    if (uri.userInfo.isNotEmpty) return false;

    final host = uri.host.toLowerCase();
    final a = apex.toLowerCase();
    final s = suffix.toLowerCase();
    return host == a || host.endsWith(s);
  }
}
