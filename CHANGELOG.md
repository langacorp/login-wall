# Changelog

All notable changes to this project are recorded here.
Dates are the date of the commit, not of a release.

## 2026-09-04

- CITATION.cff: version and date match the release. Zenodo reads this file, so a
  stale version here is a stale version in the archived record. First release
  archived by Zenodo.

## 2026-08-30

- README: link the Galaxy products the tool was built against

## 2026-08-28

- login-wall: two guards for an app that opens its own pages in a WebView
- README: say that the self-test has not been run under dart
- ci: run the self-test under a real Dart SDK, on every push
- selftest: readProbe is static, call it on the class
