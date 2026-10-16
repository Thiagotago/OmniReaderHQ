import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'comic.dart';

/// Stores favorite catalog entries locally without retaining transient UI state.
class FavoritesStore {
  static const _key = 'comic_favorites';

  Future<List<Comic>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null) return const [];
    try {
      final items = (jsonDecode(encoded) as List).cast<Map<String, dynamic>>();
      return items.map(_fromJson).toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Future<void> toggle(Comic comic) async {
    final preferences = await SharedPreferences.getInstance();
    final favorites = await load();
    final exists = favorites.any((item) => item.id == comic.id);
    final updated = exists
        ? favorites.where((item) => item.id != comic.id).toList()
        : [comic, ...favorites];
    await preferences.setString(
      _key,
      jsonEncode(updated.map(_toJson).toList()),
    );
  }

  Map<String, dynamic> _toJson(Comic comic) => {
        'id': comic.id,
        'title': comic.title,
        'description': comic.description,
        'coverColor': comic.coverColor.toARGB32(),
        'coverIcon': comic.coverIcon.codePoint,
        'coverUrl': comic.coverUrl?.toString(),
        'sourceNames': comic.sourceNames,
        'alsoFoundAt': comic.alsoFoundAt,
      };

  Comic _fromJson(Map<String, dynamic> json) => Comic(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        coverColor: Color(json['coverColor'] as int? ?? 0xFF5652A2),
        coverIcon: IconData(
          json['coverIcon'] as int? ?? 0xe3c9,
          fontFamily: 'MaterialIcons',
        ),
        coverUrl: (json['coverUrl'] as String?) == null
            ? null
            : Uri.tryParse(json['coverUrl'] as String),
        sourceNames: (json['sourceNames'] as List<dynamic>? ?? const []).cast<String>(),
        alsoFoundAt: (json['alsoFoundAt'] as List<dynamic>? ?? const []).cast<String>(),
      );
}
