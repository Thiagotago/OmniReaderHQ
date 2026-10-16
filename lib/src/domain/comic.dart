import 'package:flutter/material.dart';

class Comic {
  const Comic({
    required this.id,
    required this.title,
    this.description = '',
    this.coverColor = const Color(0xFF5652A2),
    this.coverIcon = Icons.menu_book,
    this.coverUrl,
    this.sourceNames = const [],
    this.alsoFoundAt = const [],
  });

  final String id;
  final String title;
  final String description;
  final Color coverColor;
  final IconData coverIcon;
  final Uri? coverUrl;
  final List<String> sourceNames;
  final List<String> alsoFoundAt;
}

class ComicChapter {
  const ComicChapter({
    required this.id,
    required this.comicId,
    required this.title,
    this.mockPageCount = 0,
    this.archiveUri,
  });

  final String id;
  final String comicId;
  final String title;
  final int mockPageCount;
  final Uri? archiveUri;
}
