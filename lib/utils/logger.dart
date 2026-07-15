import 'package:flutter/foundation.dart';

/// Debug-only logger. Prints nothing in release builds.
void debugLog(Object? message) {
  if (kDebugMode) {
    print(message);
  }
}
