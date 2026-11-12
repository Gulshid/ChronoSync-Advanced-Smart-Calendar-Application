import 'dart:convert';

/// Helpers for the iCalendar text format (RFC 5545).
abstract final class IcsCodec {
  /// Escapes text values: backslash, semicolon, comma and line breaks.
  static String escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\r\n', '\\n')
      .replaceAll('\n', '\\n');

  static String unescape(String value) {
    final out = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final c = value[i];
      if (c == '\\' && i + 1 < value.length) {
        final next = value[++i];
        out.write(next == 'n' || next == 'N' ? '\n' : next);
      } else {
        out.write(c);
      }
    }
    return out.toString();
  }

  /// Splits a long line into pieces of at most 75 bytes. Continuation pieces start with a space.
  static String fold(String line) {
    final out = StringBuffer();
    var bytes = 0;
    var limit = 75;
    for (final rune in line.runes) {
      final ch = String.fromCharCodes([rune]);
      final size = utf8.encode(ch).length;
      if (bytes + size > limit) {
        out.write('\r\n ');
        bytes = 0;
        limit = 74;
      }
      out.write(ch);
      bytes += size;
    }
    return out.toString();
  }

  /// Reverses [fold] and returns the logical lines.
  static List<String> unfold(String text) {
    final physical = text.replaceAll('\r\n', '\n').split('\n');
    final lines = <String>[];
    for (final line in physical) {
      if ((line.startsWith(' ') || line.startsWith('\t')) && lines.isNotEmpty) {
        lines[lines.length - 1] += line.substring(1);
      } else if (line.isNotEmpty) {
        lines.add(line);
      }
    }
    return lines;
  }

  /// Parses "NAME;PARAM=VALUE:value" into its parts.
  static IcsProperty? parseLine(String line) {
    final colon = line.indexOf(':');
    if (colon <= 0) return null;
    final head = line.substring(0, colon);
    final value = line.substring(colon + 1);
    final parts = head.split(';');
    final params = <String, String>{};
    for (final part in parts.skip(1)) {
      final eq = part.indexOf('=');
      if (eq > 0) {
        params[part.substring(0, eq).toUpperCase()] = part.substring(eq + 1).replaceAll('"', '');
      }
    }
    return IcsProperty(parts.first.toUpperCase(), params, value);
  }
}

class IcsProperty {
  const IcsProperty(this.name, this.params, this.value);

  final String name;
  final Map<String, String> params;
  final String value;
}
