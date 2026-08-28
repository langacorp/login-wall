// Self-test in both directions. No test framework, no dependencies:
// `dart run selftest.dart` and read the exit code.
//
// Direction matters more than count here. A guard that only ever fires is a
// way of signing people out; a guard that never fires is not a guard.

import 'lib/domain_guard.dart';
import 'lib/login_wall_detector.dart';

final _failures = <String>[];

void check(String name, bool got, bool want) {
  final ok = got == want;
  print('  ${ok ? ' ' : '!'} $name -> $got (want $want)');
  if (!ok) _failures.add(name);
}

void main() {
  // ─── DomainGuard ──────────────────────────────────────────────────────
  final g = DomainGuard(apex: 'example.com');

  print('DomainGuard — must ALLOW');
  check('apex itself', g.isAllowed('https://example.com/'), true);
  check('subdomain', g.isAllowed('https://app.example.com/x'), true);
  check('deep subdomain', g.isAllowed('https://a.b.example.com/'), true);
  check('uppercase host', g.isAllowed('https://APP.EXAMPLE.COM/'), true);

  print('DomainGuard — must REFUSE');
  // The one the whole class exists for: `contains` would accept this.
  check('suffix worn by another domain',
      g.isAllowed('https://example.com.someoneelse.net/'), false);
  check('userinfo before the host',
      g.isAllowed('https://example.com@elsewhere.net/'), false);
  check('http downgrade', g.isAllowed('http://example.com/'), false);
  check('custom scheme', g.isAllowed('app://example.com/'), false);
  check('unrelated host', g.isAllowed('https://elsewhere.net/'), false);
  check('null', g.isAllowed(null), false);
  check('empty', g.isAllowed(''), false);
  // Substring of the apex, not a subdomain of it.
  check('apex as a substring', g.isAllowed('https://notexample.com/'), false);

  print('DomainGuard — configuration is not hardcoded');
  final g2 = DomainGuard(apex: 'other.test');
  check('other apex allowed', g2.isAllowed('https://x.other.test/'), true);
  check('first apex now refused', g2.isAllowed('https://example.com/'), false);

  // ─── LoginWallDetector ────────────────────────────────────────────────
  final d = LoginWallDetector();

  print('LoginWallDetector — must FIRE');
  check('wp-login', d.urlLooksLikeLogin('https://x.test/wp-login.php'), true);
  // The trailing slash: the defect corrected on 19 August 2026.
  check('trailing slash', d.urlLooksLikeLogin('https://x.test/login/'), true);
  check('with query',
      d.urlLooksLikeLogin('https://x.test/login/?embed=1'), true);
  check('probe found a form', LoginWallDetector.readProbe('true'), true);
  check('both signals via isLoginWall',
      d.isLoginWall(url: 'https://x.test/login/', probeResult: 'true'), true);
  check('probe alone is enough',
      d.isLoginWall(url: 'https://x.test/dashboard', probeResult: 'true'), true);

  print('LoginWallDetector — must STAY SILENT');
  // This is the direction that costs: a false positive reconnects a person
  // who was perfectly fine.
  check('article about logging in',
      d.urlLooksLikeLogin('https://x.test/blog/how-to-login-faster'), false);
  check('product page named login',
      d.urlLooksLikeLogin('https://x.test/products/login-easy'), false);
  check('home', d.urlLooksLikeLogin('https://x.test/'), false);
  check('probe found nothing', LoginWallDetector.readProbe('false'), false);
  check('probe returned junk', LoginWallDetector.readProbe('undefined'), false);
  check('probe returned null', LoginWallDetector.readProbe(null), false);
  check('valid session, no signal',
      d.isLoginWall(url: 'https://x.test/account/orders', probeResult: 'false'),
      false);

  print('LoginWallDetector — configuration is not hardcoded');
  final d2 = LoginWallDetector(loginPaths: const ['/entrar']);
  check('custom route fires', d2.urlLooksLikeLogin('https://x.test/entrar/'), true);
  check('default route no longer fires',
      d2.urlLooksLikeLogin('https://x.test/wp-login.php'), false);

  print('');
  if (_failures.isEmpty) {
    print('self-test passed: it fires on a login wall, stays silent on a valid '
        'session, and refuses a suffix worn by another domain');
  } else {
    print('SELF-TEST FAILED');
    for (final f in _failures) {
      print('  $f');
    }
  }
}
