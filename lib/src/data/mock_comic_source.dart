import 'package:flutter/material.dart';

import '../domain/comic.dart';
import '../domain/comic_source.dart';

class MockComicSource implements ComicSource {
  static const _comics = <Comic>[
    Comic(
      id: 'starbound',
      title: 'Starbound',
      description: 'Uma tripulação atravessa uma galáxia cheia de mistérios.',
      coverColor: Color(0xFF34305E),
      coverIcon: Icons.rocket_launch,
    ),
    Comic(
      id: 'the-last-forest',
      title: 'A Última Floresta',
      description: 'Uma aventura fantástica em um mundo em transformação.',
      coverColor: Color(0xFF386A55),
      coverIcon: Icons.forest,
    ),
    Comic(
      id: 'night-watch',
      title: 'Vigília Noturna',
      description: 'Mistério e investigação nas ruas de uma cidade chuvosa.',
      coverColor: Color(0xFF304B65),
      coverIcon: Icons.nights_stay,
    ),
    Comic(
      id: 'clockwork',
      title: 'Coração Mecânico',
      description: 'Uma inventora encontra uma máquina que muda seu destino.',
      coverColor: Color(0xFF9A5939),
      coverIcon: Icons.settings,
    ),
    Comic(
      id: 'deep-blue',
      title: 'O Azul Profundo',
      description: 'Uma expedição descobre sinais de vida no oceano abissal.',
      coverColor: Color(0xFF236A80),
      coverIcon: Icons.water,
    ),
    Comic(
      id: 'paper-moon',
      title: 'Lua de Papel',
      description: 'Contos curtos sobre sonhos, memória e recomeços.',
      coverColor: Color(0xFF795C86),
      coverIcon: Icons.nightlight_round,
    ),
  ];

  @override
  Future<List<Comic>> getComics() async => _comics;

  @override
  Future<List<ComicChapter>> getChapters(String comicId) async {
    if (!_comics.any((comic) => comic.id == comicId)) return const [];
    return List.generate(
      8,
      (index) => ComicChapter(
        id: '$comicId-chapter-${index + 1}',
        comicId: comicId,
        title: 'Capítulo ${index + 1}',
        mockPageCount: 6 + (index % 3),
      ),
    );
  }
}
