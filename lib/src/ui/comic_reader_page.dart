import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/comic.dart';
import '../domain/reading_progress.dart';
import '../domain/reading_progress_store.dart';

class ComicReaderPage extends StatefulWidget {
  const ComicReaderPage({
    required this.comic,
    required this.chapter,
    required this.pagePaths,
    required this.initialPage,
    required this.progressStore,
    super.key,
  });

  final Comic comic;
  final ComicChapter chapter;
  final List<String> pagePaths;
  final int initialPage;
  final ReadingProgressStore progressStore;

  @override
  State<ComicReaderPage> createState() => _ComicReaderPageState();
}

class _ComicReaderPageState extends State<ComicReaderPage> {
  late final PageController _pageController;
  late final ScrollController _scrollController;
  late final FocusNode _focusNode;
  late int _currentPage;

  // Variável que controla se os menus estão visíveis
  bool _showControls = true;
  bool _verticalMode = false;
  int _activePointers = 0;
  double _brightness = 0;
  double _pageSpacing = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage
        .clamp(0, widget.pagePaths.isNotEmpty ? widget.pagePaths.length - 1 : 0)
        .toInt();
    _pageController = PageController(initialPage: _currentPage);
    _scrollController = ScrollController();
    _focusNode = FocusNode(debugLabel: 'Comic reader keyboard controls');
    _loadReaderPreferences();
  }

  Future<void> _loadReaderPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _verticalMode = preferences.getBool('reader_vertical_mode') ?? false;
      _brightness = preferences.getDouble('reader_brightness') ?? 0;
      _pageSpacing = preferences.getDouble('reader_page_spacing') ?? 0;
    });
    if (_verticalMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(_currentPage * _verticalItemExtent);
        }
      });
    }
  }

  double get _verticalItemExtent => _readerViewportHeight + _pageSpacing;

  Future<void> _showReaderSettings() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Acessibilidade e leitura'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(alignment: Alignment.centerLeft, child: Text('Brilho')),
            Slider(
              min: 0,
              max: .65,
              value: _brightness,
              onChanged: (value) {
                setState(() => _brightness = value);
                setDialogState(() {});
                preferences.setDouble('reader_brightness', value);
              },
            ),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Espaço entre páginas no modo vertical')),
            Slider(
              min: 0,
              max: 48,
              divisions: 12,
              value: _pageSpacing,
              onChanged: (value) {
                setState(() => _pageSpacing = value);
                setDialogState(() {});
                preferences.setDouble('reader_page_spacing', value);
              },
            ),
            const Text(
                'Atalhos: ←/→ página anterior/próxima · Home/End início/fim'),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Concluir'))
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _changePage(int page) {
    if (page < 0 || page >= widget.pagePaths.length) return;
    if (_verticalMode) {
      final height = _verticalItemExtent;
      _scrollController.animateTo(
        page * height,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } else {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _setReadingMode(bool vertical) {
    if (_verticalMode == vertical) return;
    setState(() => _verticalMode = vertical);
    SharedPreferences.getInstance().then(
        (preferences) => preferences.setBool('reader_vertical_mode', vertical));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_verticalMode && _scrollController.hasClients) {
        _scrollController.jumpTo(_currentPage * _verticalItemExtent);
      } else if (!_verticalMode && _pageController.hasClients) {
        _pageController.jumpToPage(_currentPage);
      }
    });
  }

  double get _readerViewportHeight {
    final media = MediaQuery.of(context);
    return media.size.height - media.padding.vertical;
  }

  bool _onVerticalScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical ||
        notification.metrics.viewportDimension <= 0) return false;
    final page = (notification.metrics.pixels / _verticalItemExtent)
        .round()
        .clamp(0, widget.pagePaths.length - 1)
        .toInt();
    if (page != _currentPage) {
      setState(() => _currentPage = page);
      unawaited(_saveProgress(page));
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers++;
    if (_activePointers == 2 && mounted) setState(() {});
  }

  void _onPointerUp(PointerEvent event) {
    _activePointers = (_activePointers - 1).clamp(0, 10);
    if (_activePointers < 2 && mounted) setState(() {});
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    unawaited(_saveProgress(page));
  }

  Future<void> _saveProgress(int page) {
    return widget.progressStore.save(
      ReadingProgress(
        comicId: widget.comic.id,
        comicTitle: widget.comic.title,
        chapterId: widget.chapter.id,
        chapterTitle: widget.chapter.title,
        page: page,
        totalPages: widget.pagePaths.length,
        updatedAt: DateTime.now(),
      ),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      _changePage(_currentPage + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      _changePage(_currentPage - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      _changePage(0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      _changePage(widget.pagePaths.length - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black, // Fundo totalmente preto
        body: Stack(
          children: [
            // ==========================================
            // CAMADA 1: O LEITOR DE IMAGENS (Fundo)
            // ==========================================
            Listener(
              onPointerDown: _onPointerDown,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              child: GestureDetector(
                onTap: () {
                  setState(() => _showControls = !_showControls);
                },
                child: widget.pagePaths.isEmpty
                    ? const Center(
                        child: Text('Nenhuma página encontrada.',
                            style: TextStyle(color: Colors.white)))
                    : _verticalMode
                        ? NotificationListener<ScrollNotification>(
                            onNotification: _onVerticalScroll,
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: widget.pagePaths.length,
                              itemBuilder: (context, index) => SizedBox(
                                height: _verticalItemExtent,
                                width: double.infinity,
                                child: Column(children: [
                                  SizedBox(
                                    height: _readerViewportHeight,
                                    child: InteractiveViewer(
                                      minScale: 1,
                                      maxScale: 5,
                                      scaleEnabled: true,
                                      panEnabled: true,
                                      boundaryMargin: const EdgeInsets.all(48),
                                      child: Image.file(
                                        File(widget.pagePaths[index]),
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Center(
                                          child: Text(
                                              'Erro ao carregar a página ${index + 1}',
                                              style: const TextStyle(
                                                  color: Colors.red)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: _pageSpacing),
                                ]),
                              ),
                            ),
                          )
                        : PageView.builder(
                            controller: _pageController,
                            // A pinça é um gesto de zoom, nunca de troca de página.
                            // Desativa o arrasto horizontal enquanto há dois dedos.
                            physics: _activePointers >= 2
                                ? const NeverScrollableScrollPhysics()
                                : const PageScrollPhysics(),
                            itemCount: widget.pagePaths.length,
                            onPageChanged: _onPageChanged,
                            itemBuilder: (context, index) {
                              final file = File(widget.pagePaths[index]);
                              return InteractiveViewer(
                                minScale: 1,
                                maxScale: 5,
                                scaleEnabled: true,
                                panEnabled: true,
                                boundaryMargin: const EdgeInsets.all(48),
                                child: Image.file(
                                  file,
                                  fit: BoxFit
                                      .contain, // Garante que a HQ cabe na tela
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        'Erro ao carregar a página ${index + 1}\nCaminho: ${file.path}',
                                        textAlign: TextAlign.center,
                                        style:
                                            const TextStyle(color: Colors.red),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ),
            if (_brightness > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                      color: Colors.black.withValues(alpha: _brightness)),
                ),
              ),

            // ==========================================
            // CAMADA 2: BARRA SUPERIOR FLUTUANTE
            // ==========================================
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.85),
                  padding:
                      EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                  child: Row(
                    children: [
                      IconButton(
                        visualDensity: compact ? VisualDensity.compact : null,
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Sair da Leitura',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      IconButton(
                        visualDensity: compact ? VisualDensity.compact : null,
                        tooltip: 'Configurações de leitura',
                        onPressed: _showReaderSettings,
                        icon: const Icon(Icons.tune, color: Colors.white),
                      ),
                      IconButton(
                        visualDensity: compact ? VisualDensity.compact : null,
                        tooltip:
                            _verticalMode ? 'Modo páginas' : 'Modo vertical',
                        onPressed: () => _setReadingMode(!_verticalMode),
                        icon: Icon(
                            _verticalMode
                                ? Icons.view_carousel
                                : Icons.swap_vert,
                            color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          compact
                              ? widget.chapter.title
                              : '${widget.comic.title} · ${widget.chapter.title}',
                          style: TextStyle(
                              color: Colors.white, fontSize: compact ? 12 : 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        visualDensity: compact ? VisualDensity.compact : null,
                        tooltip: 'Página anterior (←)',
                        onPressed: _currentPage == 0
                            ? null
                            : () => _changePage(_currentPage - 1),
                        icon:
                            const Icon(Icons.chevron_left, color: Colors.white),
                      ),
                      Text(
                        '${_currentPage + 1} / ${widget.pagePaths.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      IconButton(
                        visualDensity: compact ? VisualDensity.compact : null,
                        tooltip: 'Próxima página (→)',
                        onPressed: _currentPage >= widget.pagePaths.length - 1
                            ? null
                            : () => _changePage(_currentPage + 1),
                        icon: const Icon(Icons.chevron_right,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),

            // ==========================================
            // CAMADA 3: BARRA INFERIOR FLUTUANTE
            // ==========================================
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withOpacity(0.85),
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: compact ? 12 : 24, vertical: 8),
                    child: Row(
                      children: [
                        Icon(_verticalMode ? Icons.swap_vert : Icons.zoom_in,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        if (!compact)
                          const Expanded(
                            child: Text('Toque na tela para ocultar os menus',
                                style: TextStyle(color: Colors.white70)),
                          ),
                        if (!compact) const SizedBox(width: 12),
                        Expanded(
                          child: Slider(
                            min: 0,
                            max: widget.pagePaths.isEmpty
                                ? 0
                                : (widget.pagePaths.length - 1).toDouble(),
                            divisions: widget.pagePaths.length > 1
                                ? widget.pagePaths.length - 1
                                : null,
                            value: _currentPage.toDouble(),
                            onChanged: (value) => _changePage(value.round()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
