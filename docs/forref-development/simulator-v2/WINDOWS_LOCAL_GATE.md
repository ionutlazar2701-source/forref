# Windows local gate

WINDOWS APPLICATION LAUNCH: OBSERVED PASS

Evidence: founder report that Simulator Lab launched on Windows with Flutter 3.47.2 during Simulator Night I. This cloud session did not repeat that launch.

That observation is not:

- human validation
- native watch fidelity
- production D1
- device certification
- a Simulator V2 visual pass

Cloud Linux tests are not Windows runtime proof.

Local command, from the repository root on Windows:

```
cd research\hf_prototype
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Known toolchain: Flutter 3.47.2, Windows desktop, Visual Studio C++ toolchain available.

Do not treat a future Linux widget screenshot as this Windows gate.
