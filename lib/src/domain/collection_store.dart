import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'comic.dart';

class ComicCollection {
  const ComicCollection({required this.name, required this.comics});
  final String name;
  final List<Comic> comics;
}

class CollectionStore {
  static const _key = 'comic_collections';

  Future<List<ComicCollection>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_key);
    if (value == null) return const [];
    try {
      final raw = (jsonDecode(value) as Map).cast<String, dynamic>();
      return raw.entries.map((entry) => ComicCollection(
        name: entry.key,
        comics: (entry.value as List).cast<Map<String, dynamic>>().map(_decodeComic).toList(),
      )).toList();
    } on Object {
      return const [];
    }
  }

  Future<void> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final data = await _read();
    data.putIfAbsent(trimmed, () => <Map<String, dynamic>>[]);
    await _write(data);
  }

  Future<void> delete(String name) async {
    final data = await _read();
    data.remove(name);
    await _write(data);
  }

  Future<void> toggleComic(String name, Comic comic) async {
    final data = await _read();
    final items = (data[name] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    if (items.any((item) => item['id'] == comic.id)) {
      items.removeWhere((item) => item['id'] == comic.id);
    } else {
      items.add(_encodeComic(comic));
    }
    data[name] = items;
    await _write(data);
  }

  Future<Map<String, dynamic>> _read() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_key);
    if (value == null) return <String, dynamic>{};
    try {
      return (jsonDecode(value) as Map).cast<String, dynamic>();
    } on Object {
      return <String, dynamic>{};
    }
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, jsonEncode(data));
  }

  Map<String, dynamic> _encodeComic(Comic comic) => {
        'id': comic.id,
        'title': comic.title,
        'description': comic.description,
        'coverColor': comic.coverColor.toARGB32(),
        'coverIcon': comic.coverIcon.codePoint,
        'coverUrl': comic.coverUrl?.toString(),
        'sourceNames': comic.sourceNames,
        'alsoFoundAt': comic.alsoFoundAt,
      };

  Comic _decodeComic(Map<String, dynamic> data) => Comic(
        id: data['id'] as String,
        title: data['title'] as String,
        description: data['description'] as String? ?? '',
        coverColor: Color(data['coverColor'] as int? ?? 0xFF5652A2),
        coverIcon: IconData(data['coverIcon'] as int? ?? 0xe3c9, fontFamily: 'MaterialIcons'),
        coverUrl: data['coverUrl'] == null ? null : Uri.tryParse(data['coverUrl'] as String),
        sourceNames: (data['sourceNames'] as List<dynamic>? ?? const []).cast<String>(),
        alsoFoundAt: (data['alsoFoundAt'] as List<dynamic>? ?? const []).cast<String>(),
      );
}
