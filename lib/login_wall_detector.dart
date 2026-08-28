/// Recognise that a service has shown us ITS OWN login screen.
///
/// It is needed because the cookie can fall before the token: session expired
/// server-side, cookie jar cleared by the system, WebView rebuilt after Android
/// evicted the process. Without this, the person is shown a site's sign-in page
/// inside an app they are already signed into, and does not understand why.
///
/// TWO SIGNALS, both by PRESENCE and never by absence:
///   - the address is a known sign-in route;
///   - the page contains a sign-in form.
///
/// The obvious signal would be the ABSENCE of a `logged-in` class on the body,
/// and it is deliberately discarded: not every service is WordPress, and on the
/// others the absence would always be true. A signal that is always on across
/// three services is not a signal — it is a way of signing people out.
///
/// No route and no selector is hardcoded to any one platform beyond the
/// defaults below, and the caller can replace both.
class LoginWallDetector {
  /// Sign-in routes, without a trailing slash.
  final List<String> loginPaths;

  /// CSS selector list used by [probeJs] to find a real sign-in form.
  final String formSelector;

  LoginWallDetector({
    List<String>? loginPaths,
    String? formSelector,
  })  : loginPaths = loginPaths ?? const ['/wp-login.php', '/login', '/sign-in'],
        formSelector = formSelector ??
            'form#loginform, form.woocommerce-form-login, '
                'input[name="log"], input[name="pwd"], '
                'form[action*="wp-login.php"]';

  /// Address side. Conservative on purpose: better to miss it and let the
  /// person see the login, than to reconnect someone who was perfectly fine.
  bool urlLooksLikeLogin(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    // THE TRAILING SLASH. Until 19 August 2026 the comparison was on the raw
    // path, and '/login/' did NOT match '/login': WordPress always redirects to
    // the form with the slash, so the real address was never recognised.
    // Measured on a phone: the app let a `/login/?embed=1` page through and the
    // person signed in through the web — the exact double identity this is
    // meant to prevent.
    var path = uri.path.toLowerCase();
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    for (final p in loginPaths) {
      final q = p.toLowerCase();
      if (path == q || path.endsWith(q)) return true;
    }
    return false;
  }

  /// Content side, evaluated inside the page. Looks for a real sign-in form.
  String get probeJs => '''
(function () {
  try {
    var sel = ${_jsString(formSelector)};
    return document.querySelector(sel) ? 'true' : 'false';
  } catch (e) { return 'false'; }
})();
''';

  static String _jsString(String s) =>
      "'" + s.replaceAll(r'\', r'\\').replaceAll("'", r"\'") + "'";

  /// Reads whatever the WebView returned. Anything that is not exactly `true`
  /// is read as false: an unparsable answer is not a positive.
  static bool readProbe(Object? raw) {
    final s = raw?.toString().replaceAll('"', '').trim().toLowerCase();
    return s == 'true';
  }

  /// Both signals together. Either one alone is enough — they are independent,
  /// and each covers a case the other misses.
  bool isLoginWall({String? url, Object? probeResult}) {
    if (url != null && urlLooksLikeLogin(url)) return true;
    if (probeResult != null && readProbe(probeResult)) return true;
    return false;
  }

  /// STATED LIMIT: a non-WordPress service with a sign-in form written its own
  /// way is recognised by neither signal. In that case the person sees the
  /// site's login and has to leave and come back. The selector gets added when
  /// that service actually exists, not before: selectors written for imaginary
  /// sites are the reason lists like this become unreadable.
  static const String limit =
      'Recognises WordPress and WooCommerce by default. A custom non-WP login '
      'is not recognised unless a selector is supplied.';
}
