import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/catalog_source_config.dart';

class CatalogSourceStore {
  static const _key = 'catalog_sources_v1';

  Future<List<CatalogSourceConfig>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null) return const [];
    try {
      final decoded = (jsonDecode(encoded) as List)
          .cast<Map<String, dynamic>>()
          .map(CatalogSourceConfig.fromJson)
          .toList();
      final unique = <String, CatalogSourceConfig>{};
      for (final config in decoded) {
        final existing = unique[config.id];
        if (existing == null || (!existing.isPrimary && config.isPrimary)) {
          unique[config.id] = config;
        }
      }
      final configs = unique.values.toList();
      if (configs.isEmpty) return const [];
      var primaryIndex = configs.indexWhere((config) => config.isPrimary);
      if (primaryIndex < 0) primaryIndex = 0;
      for (var index = 0; index < configs.length; index++) {
        configs[index] = configs[index].copyWith(
          isPrimary: index == primaryIndex,
          enabled: index == primaryIndex ? true : configs[index].enabled,
        );
      }
      configs
          .sort((a, b) => (b.isPrimary ? 1 : 0).compareTo(a.isPrimary ? 1 : 0));
      if (configs.length != decoded.length) {
        await preferences.setString(
          _key,
          jsonEncode(configs.map((config) => config.toJson()).toList()),
        );
      }
      return configs;
    } on Object {
      return const [];
    }
  }

  Future<void> save(List<CatalogSourceConfig> configs) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        _key, jsonEncode(configs.map((config) => config.toJson()).toList()));
  }
}
