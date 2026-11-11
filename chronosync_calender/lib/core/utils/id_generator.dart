import 'dart:math';

final _random = Random.secure();

/// Unique id from microsecond time plus random bits. Enough for a single device.
String newId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final noise = _random.nextInt(1 << 32).toRadixString(36);
  return '$time$noise';
}
