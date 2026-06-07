import 'package:flutter/foundation.dart';

/// Lightweight diagnostic logging for the remote backends.
///
/// Network remotes fail in many small, recoverable ways (a dropped keypress,
/// an unreachable box during discovery). We don't want those to crash the UI,
/// but swallowing them silently makes field issues impossible to diagnose.
/// `atvLog` prints in debug/profile builds and is a no-op in release, so the
/// shipped app stays quiet while development keeps visibility.
void atvLog(String where, Object error, [StackTrace? stack]) {
  if (kReleaseMode) return;
  debugPrint('[atv] $where: $error');
}
