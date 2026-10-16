import 'dart:io';

class CatalogSourceConfig {
  const CatalogSourceConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.enabled = true,
    this.isPrimary = false,
  });

  final String id;
  final String name;
  final String baseUrl;
  final bool enabled;
  final bool isPrimary;

  CatalogSourceConfig copyWith({
    bool? enabled,
    bool? isPrimary,
  }) =>
      CatalogSourceConfig(
        id: id,
        name: name,
        baseUrl: baseUrl,
        enabled: enabled ?? this.enabled,
        isPrimary: isPrimary ?? this.isPrimary,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'enabled': enabled,
        'isPrimary': isPrimary,
      };

  factory CatalogSourceConfig.fromJson(Map<String, dynamic> json) =>
      CatalogSourceConfig(
        id: normalizedId(json['baseUrl'] as String),
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String,
        enabled: json['enabled'] as bool? ?? true,
        isPrimary: json['isPrimary'] as bool? ?? false,
      );

  static CatalogSourceConfig fromUrl(
    String name,
    String rawUrl, {
    bool primary = false,
  }) {
    final uri = Uri.parse(rawUrl.trim());
    if ((uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
          'Use um endereço HTTP ou HTTPS válido, sem usuário ou senha.');
    }
    final host = uri.host.toLowerCase();
    final address = InternetAddress.tryParse(host);
    final parts = host.split('.').map(int.tryParse).toList();
    final privateIpv4 = parts.length == 4 &&
        parts.every((part) => part != null) &&
        (parts[0] == 10 ||
            parts[0] == 127 ||
            parts[0] == 0 ||
            (parts[0] == 192 && parts[1] == 168) ||
            (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31) ||
            (parts[0] == 169 && parts[1] == 254));
    if (host == 'localhost' ||
        host.endsWith('.local') ||
        privateIpv4 ||
        (address != null && (address.isLoopback || address.isLinkLocal)) ||
        host.startsWith('fc') ||
        host.startsWith('fd')) {
      throw const FormatException(
          'Use o endereço público do site, não um endereço local.');
    }
    final normalized = normalizedUrl(rawUrl);
    return CatalogSourceConfig(
      id: normalized.toLowerCase(),
      name: name.trim().isEmpty ? uri.host : name.trim(),
      baseUrl: normalized,
      isPrimary: primary,
    );
  }

  static String normalizedId(String rawUrl) {
    return normalizedUrl(rawUrl).toLowerCase();
  }

  static String normalizedUrl(String rawUrl) {
    final uri = Uri.parse(rawUrl.trim());
    var normalized = uri.replace(query: '', fragment: '').toString();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
