# login-wall

[![self-test](https://github.com/langacorp/login-wall/actions/workflows/selftest.yml/badge.svg)](https://github.com/langacorp/login-wall/actions/workflows/selftest.yml)

Two small guards for an app that opens its own web pages in a WebView.

**`DomainGuard`** — is this URL ours, really?
**`LoginWallDetector`** — has this page just shown the person a sign-in screen?

No dependencies. No domain hardcoded. Both are plain classes: a string in, a
boolean out.

---

## The defects they were born from

### 14 August 2026 — `contains` accepts a domain that is not yours

A URL check compared hosts with `contains`. That accepts
`example.com.someoneelse.net` — which is not a typo, it is **the shape used to
carry a user's session onto somebody else's server**. The app would have opened
it inside its own WebView, with the session attached.

The comparison is now on the **suffix**, and `https://example.com@elsewhere.net/`
is refused too: the host there is `elsewhere.net`, but most people read the part
before the `@`.

The check is repeated at three points in the host app — reading the list,
opening the WebView, internal navigation — because a single point is a point
that somebody eventually works around without noticing.

### 14 → 19 August 2026 — the cookie falls before the token

A session can expire server-side, the cookie jar can be cleared by the system,
the WebView can be rebuilt after Android evicts the process. When that happens
the person is shown a site's sign-in page **inside an app they are already
signed into**, and does not understand why.

Two signals detect it, both by **presence** and never by absence:

- the address is a known sign-in route;
- the page contains a sign-in form.

**The obvious signal was discarded on purpose.** It would have been the
*absence* of a `logged-in` class on the body — but not every service is
WordPress, and on the others the absence would always be true. *A signal that is
always on across three services is not a signal; it is a way of signing people
out.*

**19 August 2026, the trailing slash.** Until that day the comparison was on the
raw path, and `/login/` did not match `/login`. WordPress always redirects to the
form with the slash, so the real address was never recognised. Measured on a
phone: the app let a `/login/?embed=1` page through and the person signed in
through the web — the exact double identity this exists to prevent.

---

## Prove it before you trust it

```
dart run selftest.dart
```

The badge above is that same run, under a real Dart SDK, on every push. It is
the difference between *the cases passed* and *the cases pass today*: you can
check instead of taking our word for it.

Both directions, and the silent one is the one that costs:

| must fire | must stay silent |
|---|---|
| `/wp-login.php` | `/blog/how-to-login-faster` |
| `/login/` — with the slash | `/products/login-easy` |
| `/login/?embed=1` | `/account/orders` with a valid session |
| a sign-in form found in the page | a probe that returned junk or nothing |

| must allow | must refuse |
|---|---|
| `https://example.com/` | `https://example.com.someoneelse.net/` |
| `https://app.example.com/` | `https://example.com@elsewhere.net/` |
| `https://APP.EXAMPLE.COM/` | `http://example.com/` — downgrade |
| | `https://notexample.com/` — substring, not subdomain |

Two more cases check that the configuration is really external: give a different
apex and the first one stops being allowed; give a different route list and the
default stops firing.

---

## Use

```dart
final guard = DomainGuard(apex: 'example.com');
if (!guard.isAllowed(url)) return; // don't open it in our WebView

final detector = LoginWallDetector();
final probe = await webView.runJavaScriptReturningResult(detector.probeJs);
if (detector.isLoginWall(url: url, probeResult: probe)) {
  // the session fell — re-authenticate silently, don't show the site's login
}
```

`DomainGuard` takes `apex`, optionally `suffix` and `allowedSchemes`.
`LoginWallDetector` takes `loginPaths` and `formSelector`. Nothing is baked in.

---

## Limits, stated

- **A custom non-WordPress login is not recognised** by either signal. The
  person sees the site's sign-in page and has to leave and come back. The
  selector gets added when that service actually exists, not before: selectors
  written for imaginary sites are the reason lists like this become unreadable.
- **`DomainGuard` checks the host, not the content.** A page on your own domain
  that embeds someone else's form is allowed, and should be — that is the host
  app's problem, not this class's.
- **The address check is deliberately conservative.** It would rather miss a
  login wall than fire on a page that merely mentions logging in, because a
  false positive reconnects a person who was perfectly fine.

---

## Where this comes from

LANGA runs 16 digital services across 5 networks on its own infrastructure. This
tool came out of a defect we hit while running them. See
[How we work](https://about.langa.tv/how-we-work/).

---

## License

MIT. See `LICENSE`.

---

Built and maintained by LANGA.
