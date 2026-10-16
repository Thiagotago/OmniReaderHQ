import 'package:flutter/material.dart';

import '../domain/comic.dart';

class ComicGrid extends StatelessWidget {
  const ComicGrid(
      {required this.comics,
      required this.onOpenComic,
      this.favoriteIds = const {},
      this.onToggleFavorite,
      this.onAddToCollection,
      super.key});

  final List<Comic> comics;
  final ValueChanged<Comic> onOpenComic;
  final Set<String> favoriteIds;
  final ValueChanged<Comic>? onToggleFavorite;
  final ValueChanged<Comic>? onAddToCollection;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final columns = (constraints.maxWidth / (compact ? 160 : 220))
            .floor()
            .clamp(2, 6)
            .toInt();
        final horizontalPadding = compact ? 16.0 : 28.0;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, compact ? 20 : 28, horizontalPadding, 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HQs',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 6),
                    const Text('Catálogo local de demonstração'),
                  ],
                ),
              ),
            ),
            if (comics.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('Nenhuma HQ nesta fonte.')),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    horizontalPadding, 4, horizontalPadding, 24),
                sliver: SliverGrid.builder(
                  itemCount: comics.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: compact ? .60 : .68,
                  ),
                  itemBuilder: (context, index) {
                    final comic = comics[index];
                    return _ComicCard(
                      comic: comic,
                      onTap: () => onOpenComic(comic),
                      isFavorite: favoriteIds.contains(comic.id),
                      onToggleFavorite: onToggleFavorite == null
                          ? null
                          : () => onToggleFavorite!(comic),
                      onAddToCollection: onAddToCollection == null
                          ? null
                          : () => onAddToCollection!(comic),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ComicCard extends StatelessWidget {
  const _ComicCard(
      {required this.comic,
      required this.onTap,
      required this.isFavorite,
      this.onToggleFavorite,
      this.onAddToCollection});

  final Comic comic;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToCollection;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Abrir ${comic.title}',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(children: [
                Positioned.fill(child: ComicCover(comic: comic)),
                if (onToggleFavorite != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton.filledTonal(
                      tooltip: isFavorite
                          ? 'Remover dos favoritos'
                          : 'Adicionar aos favoritos',
                      onPressed: onToggleFavorite,
                      icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border),
                    ),
                  ),
                if (onAddToCollection != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: IconButton.filledTonal(
                      tooltip: 'Adicionar a uma coleção',
                      onPressed: onAddToCollection,
                      icon: const Icon(Icons.create_new_folder_outlined),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 10),
            Text(
              comic.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 3),
            Text(
              comic.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (comic.sourceNames.isNotEmpty)
              Text(
                'Fonte principal: ${comic.sourceNames.first}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            if (comic.alsoFoundAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Também em: ${comic.alsoFoundAt.join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ComicCover extends StatelessWidget {
  const ComicCover({required this.comic, super.key});

  final Comic comic;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: .69,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [comic.coverColor, comic.coverColor.withValues(alpha: .68)],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (comic.coverUrl != null)
              Positioned.fill(
                child: Image.network(
                  comic.coverUrl.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(),
                ),
              ),
            Positioned(
              right: -22,
              top: 28,
              child: Icon(
                comic.coverIcon,
                size: 150,
                color: Colors.white.withValues(alpha: .12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white70),
                  const Spacer(),
                  Icon(comic.coverIcon, color: Colors.white, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    comic.title.toUpperCase(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text('EDIÇÃO DE AMOSTRA',
                      style: TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
