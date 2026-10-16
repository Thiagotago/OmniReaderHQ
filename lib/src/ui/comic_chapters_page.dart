import 'package:flutter/material.dart';

import '../domain/comic.dart';
import '../domain/comic_source.dart';
import 'comic_grid.dart';

class ComicChaptersPage extends StatefulWidget {
  const ComicChaptersPage({
    required this.comic,
    required this.source,
    required this.onReadChapter,
    super.key,
  });

  final Comic comic;
  final ComicSource source;
  final Future<void> Function(ComicChapter chapter) onReadChapter;

  @override
  State<ComicChaptersPage> createState() => _ComicChaptersPageState();
}

class _ComicChaptersPageState extends State<ComicChaptersPage> {
  late Future<List<ComicChapter>> _chaptersFuture;
  String? _openingChapterId;

  @override
  void initState() {
    super.initState();
    _chaptersFuture = widget.source.getChapters(widget.comic.id);
  }

  Future<void> _openChapter(ComicChapter chapter) async {
    setState(() => _openingChapterId = chapter.id);
    try {
      await widget.onReadChapter(chapter);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível preparar o capítulo: $error')),
      );
    } finally {
      if (mounted) setState(() => _openingChapterId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.comic.title)),
      body: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final chapterList = FutureBuilder<List<ComicChapter>>(
          future: _chaptersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('Erro ao carregar capítulos: ${snapshot.error}'));
            }
            final chapters = snapshot.data ?? const <ComicChapter>[];
            return ListView(
              padding: const EdgeInsets.all(28),
              children: [
                Text('Capítulos',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                const Text('Escolha um capítulo para preparar a leitura.'),
                const SizedBox(height: 18),
                if (_openingChapterId != null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(),
                  ),
                for (final chapter in chapters)
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                          child: Icon(Icons.article_outlined)),
                      title: Text(chapter.title),
                      subtitle: Text('${chapter.mockPageCount} páginas'),
                      trailing: _openingChapterId == chapter.id
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      enabled: _openingChapterId == null,
                      onTap: _openingChapterId == null
                          ? () => _openChapter(chapter)
                          : null,
                    ),
                  ),
              ],
            );
          },
        );
        if (compact) {
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SizedBox(
                height: 112,
                child: Row(children: [
                  SizedBox(
                    width: 76,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ComicCover(comic: widget.comic),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.comic.description,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ]),
              ),
            ),
            Expanded(child: chapterList),
          ]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 240,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: ComicCover(comic: widget.comic)),
                    const SizedBox(height: 16),
                    Text(widget.comic.description),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: chapterList),
          ],
        );
      }),
    );
  }
}
