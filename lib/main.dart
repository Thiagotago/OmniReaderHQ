import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/data/blogger_source.dart';
import 'src/data/catalog_source_store.dart';
import 'src/data/remote_archive_service.dart';

import 'src/domain/comic.dart';
import 'src/domain/comic_archive_provider.dart';
import 'src/domain/favorites_store.dart';
import 'src/data/storage_manager.dart';
import 'src/data/backup_service.dart';
import 'src/domain/collection_store.dart';
import 'src/domain/reading_history_store.dart';
import 'src/domain/catalog_search.dart';
import 'src/domain/reading_status.dart';
import 'src/domain/catalog_source_config.dart';
import 'src/domain/catalog_source.dart';
import 'src/ui/comic_chapters_page.dart';
import 'src/ui/comic_grid.dart';
import 'src/ui/comic_reader_page.dart';

CatalogSource _catalogSourceFromConfig(CatalogSourceConfig config) =>
    BloggerSource(baseUrl: config.baseUrl);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ComicCatalogApp());
}

class ComicCatalogApp extends StatelessWidget {
  const ComicCatalogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniReader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5652A2)),
        useMaterial3: true,
      ),
      home: const SourceBootstrap(),
    );
  }
}

class SourceBootstrap extends StatefulWidget {
  const SourceBootstrap({super.key});

  @override
  State<SourceBootstrap> createState() => _SourceBootstrapState();
}

class _SourceBootstrapState extends State<SourceBootstrap> {
  static const _sourceUrlKey = 'catalog_base_url';
  CatalogSource? _source;
  String? _error;
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedSource();
  }

  Future<void> _loadSavedSource() async {
    final preferences = await SharedPreferences.getInstance();
    final savedUrl = preferences.getString(_sourceUrlKey)?.trim();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      try {
        await _activateSource(savedUrl);
        return;
      } on FormatException {
        await preferences.remove(_sourceUrlKey);
      }
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSourcePrompt());
  }

  Future<void> _activateSource(String rawUrl) async {
    final config = CatalogSourceConfig.fromUrl('', rawUrl);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sourceUrlKey, config.baseUrl);
    if (mounted) {
      setState(() {
        _source = BloggerSource(baseUrl: config.baseUrl);
        _error = null;
      });
    }
  }

  Future<void> _showSourcePrompt() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Configure a fonte do catálogo'),
            content: SizedBox(
              width: 420,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'Cole a URL pública de um blog no template Blogger.'),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'URL do blog',
                    hintText: 'https://seu-blog.example',
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _saveSourceUrl(setDialogState),
                ),
              ]),
            ),
            actions: [
              FilledButton(
                onPressed: () => _saveSourceUrl(setDialogState),
                child: const Text('Salvar e continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSourceUrl(
      void Function(VoidCallback) setDialogState) async {
    try {
      final config = CatalogSourceConfig.fromUrl('', _urlController.text);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_sourceUrlKey, config.baseUrl);
      if (!mounted) return;
      setState(() => _source = BloggerSource(baseUrl: config.baseUrl));
      if (context.mounted) Navigator.of(context).pop();
    } on FormatException catch (error) {
      setDialogState(() => _error = error.message);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    if (source != null) {
      return CatalogHome(
        source: source,
        archiveService: const RemoteArchiveService(),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class CatalogHome extends StatefulWidget {
  const CatalogHome({
    required this.source,
    required this.archiveService,
    super.key,
  });

  final CatalogSource source;
  final ComicArchiveProvider archiveService;

  @override
  State<CatalogHome> createState() => _CatalogHomeState();
}

class _CatalogHomeState extends State<CatalogHome> {
  static const _activeSourceKey = 'catalog_active_source_id';
  final CatalogSourceStore _sourceStore = CatalogSourceStore();
  late CatalogSource _activeSource;
  String? _activeSourceId;
  int _selectedTab = 0;
  Future<List<Comic>> _comicsFuture = Future.value(const <Comic>[]);
  List<Map<String, dynamic>> _history = [];
  final FavoritesStore _favoritesStore = FavoritesStore();
  final ReadingHistoryStore _historyStore = ReadingHistoryStore();
  final CollectionStore _collectionStore = CollectionStore();
  final BackupService _backupService = BackupService();
  final CatalogSearch _catalogSearch = const CatalogSearch();
  final ReadingStatus _readingStatus = const ReadingStatus();
  final StorageManager _storageManager = StorageManager();
  final TextEditingController _searchController = TextEditingController();
  List<Comic> _favorites = [];
  List<ComicCollection> _collections = [];
  List<CatalogSourceConfig> _sourceConfigs = [];
  int _catalogRequestId = 0;
  int _currentPage = 1;
  List<Comic> _loadedComics = [];
  bool _isLoadingMore = false;
  bool _hasMorePages = true;
  String _searchQuery = '';
  int? _storageBytes;
  List<StoredComic> _storedComics = [];
  Map<String, Set<String>> _storedChapterIndex = {};
  Map<String, Set<String>> _completedChapterIndex = {};
  Map<String, String> _storedTitleIndex = {};
  String _historyFilter = 'Todas';
  String _historySort = 'Recentes';
  String _storageSort = 'Espaço';
  String _catalogFilter = 'Todas';
  int _weeklyGoal = 5;
  final Set<String> _selectedStoredComicIds = {};

  // Variáveis para as Categorias
  List<String> _categories = [];
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _activeSource = widget.source;
    _initializeSources();
    _loadProgress();
    _loadWeeklyGoal();
    _loadFavorites();
    _loadCollections();
    _loadStorageUsage();
  }

  Future<void> _initializeSources() async {
    final preferences = await SharedPreferences.getInstance();
    var configs = await _sourceStore.load();
    if (configs.isEmpty) {
      configs = [
        CatalogSourceConfig.fromUrl('', widget.source.baseUrl, primary: true)
      ];
      await _sourceStore.save(configs);
    }
    final requestedId = preferences.getString(_activeSourceKey);
    final selected =
        configs.where((config) => config.id == requestedId).firstOrNull ??
            configs.first;
    await preferences.setString(_activeSourceKey, selected.id);
    if (!mounted) return;
    setState(() {
      _sourceConfigs = configs;
      _activeSourceId = selected.id;
      _activeSource = _catalogSourceFromConfig(selected);
    });
    await _loadCategories();
    _loadComics();
  }

  Future<void> _saveSources(List<CatalogSourceConfig> configs,
      {required String activeId}) async {
    final normalized = configs
        .map((config) => config.copyWith(isPrimary: config.id == activeId))
        .toList(growable: false);
    await _sourceStore.save(normalized);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_activeSourceKey, activeId);
    if (!mounted) return;
    setState(() {
      _sourceConfigs = normalized;
      _activeSourceId = activeId;
    });
  }

  Future<void> _selectSource(CatalogSourceConfig config) async {
    if (config.id == _activeSourceId) return;
    await _saveSources(_sourceConfigs, activeId: config.id);
    if (!mounted) return;
    setState(() {
      _activeSource = _catalogSourceFromConfig(config);
      _categories = [];
      _selectedCategory = null;
    });
    _loadComics();
    await _loadCategories();
  }

  Future<void> _addSource(String rawUrl) async {
    final config = CatalogSourceConfig.fromUrl('', rawUrl);
    final existingIndex =
        _sourceConfigs.indexWhere((existing) => existing.id == config.id);
    if (existingIndex >= 0) {
      await _saveSources(_sourceConfigs, activeId: config.id);
      if (!mounted) return;
      setState(() {
        _activeSource = _catalogSourceFromConfig(_sourceConfigs[existingIndex]);
        _categories = [];
        _selectedCategory = null;
      });
      _loadComics();
      await _loadCategories();
      return;
    }
    final updated = [..._sourceConfigs, config];
    await _saveSources(updated, activeId: config.id);
    if (!mounted) return;
    setState(() {
      _activeSource = _catalogSourceFromConfig(config);
      _categories = [];
      _selectedCategory = null;
    });
    _loadComics();
    await _loadCategories();
  }

  Future<void> _removeSource(CatalogSourceConfig config) async {
    if (_sourceConfigs.length <= 1) return;
    final wasActive = config.id == _activeSourceId;
    final updated =
        _sourceConfigs.where((item) => item.id != config.id).toList();
    final next = wasActive
        ? updated.first
        : updated.firstWhere((item) => item.id == _activeSourceId);
    await _saveSources(updated, activeId: next.id);
    if (wasActive) {
      if (!mounted) return;
      setState(() {
        _activeSource = _catalogSourceFromConfig(next);
        _categories = [];
        _selectedCategory = null;
      });
      _loadComics();
      await _loadCategories();
    }
  }

  // Carrega a lista de Heróis disponíveis
  Future<void> _loadCategories() async {
    final sourceId = _activeSourceId;
    final source = _activeSource;
    List<String> cats;
    try {
      cats = await source.getCategories();
    } on Object {
      cats = <String>[];
    }
    cats = cats.toSet().toList()..sort();
    if (mounted && sourceId == _activeSourceId) {
      setState(() {
        _categories = cats;
      });
    }
  }

  // Carrega as HQs filtradas pela Categoria selecionada
  void _loadComics() {
    final requestId = ++_catalogRequestId;
    setState(() {
      _currentPage = 1;
      _loadedComics = [];
      _hasMorePages = true;
      _isLoadingMore = false;
      _comicsFuture = _fetchComics(requestId, page: 1).then((comics) {
        if (mounted && requestId == _catalogRequestId) {
          setState(() {
            _loadedComics = comics;
            _hasMorePages = comics.isNotEmpty;
          });
        }
        return comics;
      });
    });
  }

  Future<List<Comic>> _fetchComics(int requestId, {required int page}) async {
    try {
      final comics = await _activeSource.getComicsByCategory(
        _selectedCategory,
        page,
      );
      return requestId == _catalogRequestId ? comics : const <Comic>[];
    } on Object {
      return const <Comic>[];
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || !_hasMorePages) return;
    final requestId = _catalogRequestId;
    final nextPage = _currentPage + 1;
    setState(() => _isLoadingMore = true);
    final nextComics = await _fetchComics(requestId, page: nextPage);
    if (!mounted) return;
    setState(() {
      if (requestId == _catalogRequestId) {
        final knownIds = _loadedComics.map((comic) => comic.id).toSet();
        _loadedComics.addAll(
          nextComics.where((comic) => knownIds.add(comic.id)),
        );
        _currentPage = nextPage;
        _hasMorePages = nextComics.isNotEmpty;
      }
      _isLoadingMore = false;
    });
  }

  Future<void> _loadFavorites() async {
    final favorites = await _favoritesStore.load();
    if (mounted) setState(() => _favorites = favorites);
  }

  Future<void> _loadCollections() async {
    final collections = await _collectionStore.load();
    if (mounted) setState(() => _collections = collections);
  }

  Future<void> _toggleComicInCollection(Comic comic) async {
    if (_collections.isEmpty) {
      await _createCollection();
      await _loadCollections();
      if (_collections.isEmpty) return;
    }
    final selectedName = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Adicionar/remover de coleção'),
        children: [
          for (final collection in _collections)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, collection.name),
              child: Text(collection.name),
            )
        ],
      ),
    );
    if (selectedName == null) return;
    await _collectionStore.toggleComic(selectedName, comic);
    await _loadCollections();
  }

  Future<void> _createCollection() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova coleção'),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Criar')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _collectionStore.create(name);
    await _loadCollections();
  }

  Future<void> _backupAction({required bool restore}) async {
    try {
      if (restore) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restaurar backup?'),
            content: const Text(
                'As preferências e os dados locais atuais incluídos no backup serão substituídos.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Restaurar')),
            ],
          ),
        );
        if (confirmed != true) return;
      }
      final file = restore ? null : await _backupService.exportBackup();
      if (restore) await _backupService.restoreBackup();
      await _loadProgress();
      await _loadFavorites();
      await _loadCollections();
      await _loadStorageUsage();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            restore ? 'Backup restaurado.' : 'Backup salvo em ${file!.path}'),
      ));
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falha no backup: $error')));
    }
  }

  Future<void> _toggleFavorite(Comic comic) async {
    await _favoritesStore.toggle(comic);
    await _loadFavorites();
  }

  Future<void> _loadStorageUsage() async {
    final results = await Future.wait([
      _storageManager.getUsedBytes(),
      _storageManager.listStoredComics(),
      _storageManager.loadChapterIndex(),
      _storageManager.loadTitleIndex(),
      _storageManager.loadCompletedChapterIndex(),
    ]);
    if (mounted) {
      setState(() {
        _storageBytes = results[0] as int;
        _storedComics = results[1] as List<StoredComic>;
        _storedChapterIndex = results[2] as Map<String, Set<String>>;
        _storedTitleIndex = results[3] as Map<String, String>;
        _completedChapterIndex = results[4] as Map<String, Set<String>>;
      });
    }
  }

  List<Comic> _filterComics(List<Comic> comics) {
    final query = _catalogSearch.normalize(_searchQuery);
    return comics.where((comic) {
      final itemProgress =
          _history.where((item) => item['comicId'] == comic.id).toList();
      final hasProgress = itemProgress.isNotEmpty;
      final latest = itemProgress.isEmpty ? null : itemProgress.first;
      final isRead = latest != null &&
          _readingStatus.isChapterComplete(
            totalPages: latest['totalPages'] as int? ?? 0,
            page: latest['page'] as int? ?? 0,
          );
      if (_catalogFilter == 'Favoritos' &&
          !_favorites.any((favorite) => favorite.id == comic.id)) return false;
      if (_catalogFilter == 'Em andamento' && (!hasProgress || isRead))
        return false;
      if (_catalogFilter == 'Lidas' && !isRead) return false;
      if (query.isEmpty) return true;
      final categories = _activeSource.categoriesForComic(comic.id).join(' ');
      return _catalogSearch.matches(comic, query,
          categories: categories.split(' '));
    }).toList(growable: false);
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar cache local?'),
        content: const Text(
            'As páginas extraídas serão removidas. Elas poderão ser recriadas ao abrir os capítulos novamente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Limpar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storageManager.clear();
    await _storageManager.clearIndex();
    await _loadStorageUsage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache local removido.')),
      );
    }
  }

  Future<void> _deleteStoredComic(StoredComic comic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${comic.title}?'),
        content: Text(
            'Serão removidos ${_formatBytesForDialog(comic.bytes)} de arquivos locais desta HQ.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storageManager.deleteComic(comic.id);
    await _loadStorageUsage();
  }

  Future<void> _deleteStoredChapter(
      StoredComic comic, StoredChapter chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover capítulo?'),
        content: Text(
            'Serão removidos ${_formatBytesForDialog(chapter.bytes)}. O histórico de leitura será mantido.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storageManager.deleteChapter(comic.id, chapter.id);
    await _loadStorageUsage();
  }

  bool _comicIsRead(StoredComic stored) {
    final title = _storedTitleIndex[stored.id];
    if (title == null || title.isEmpty) return false;
    final downloadedChapters =
        _storedChapterIndex[stored.id] ?? const <String>{};
    if (downloadedChapters.isEmpty) return false;
    final progress = _history.where((item) =>
        _catalogSearch.normalize(item['comicTitle'] as String? ?? '') ==
        _catalogSearch.normalize(title));
    final completedChapterIds = progress
        .where((item) => _readingStatus.isChapterComplete(
              totalPages: item['totalPages'] as int? ?? 0,
              page: item['page'] as int? ?? 0,
            ))
        .map((item) => item['chapterId'] as String)
        .toSet();
    final completedInStorage =
        _completedChapterIndex[stored.id] ?? const <String>{};
    return _readingStatus.areDownloadedChaptersComplete(
      downloadedChapterIds: downloadedChapters,
      completedChapterIds: completedChapterIds..addAll(completedInStorage),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final history = await _historyStore.load();
    if (mounted) {
      setState(() {
        _history = history;
      });
    }
  }

  Future<void> _loadWeeklyGoal() async {
    final preferences = await SharedPreferences.getInstance();
    final goal = preferences.getInt('weekly_reading_goal') ?? 5;
    if (mounted) setState(() => _weeklyGoal = goal.clamp(1, 100).toInt());
  }

  Future<void> _setWeeklyGoal(int goal) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('weekly_reading_goal', goal);
    if (mounted) setState(() => _weeklyGoal = goal);
  }

  Future<void> _deleteSelectedStoredComics() async {
    final selected = _storedComics
        .where((comic) => _selectedStoredComicIds.contains(comic.id))
        .toList();
    if (selected.isEmpty) return;
    final bytes = selected.fold<int>(0, (sum, comic) => sum + comic.bytes);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${selected.length} HQ(s)?'),
        content: Text(
            'Você liberará ${_formatBytesForDialog(bytes)}. Os arquivos selecionados serão removidos do dispositivo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final comic in selected) {
      await _storageManager.deleteComic(comic.id);
    }
    _selectedStoredComicIds.clear();
    await _loadStorageUsage();
  }

  String _formatBytesForDialog(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  int _completedChapters() => _history.where((item) {
        final updated = DateTime.tryParse(item['updatedAt'] as String? ?? '');
        if (updated == null ||
            updated.isBefore(DateTime.now().subtract(const Duration(days: 7))))
          return false;
        return _readingStatus.isChapterComplete(
          totalPages: item['totalPages'] as int? ?? 0,
          page: item['page'] as int? ?? 0,
        );
      }).length;

  int _pagesReadThisWeek() {
    final since = DateTime.now().subtract(const Duration(days: 7));
    return _history.where((item) {
      final updated = DateTime.tryParse(item['updatedAt'] as String? ?? '');
      return updated != null && updated.isAfter(since);
    }).fold(0, (sum, item) => sum + ((item['page'] as int? ?? 0) + 1));
  }

  List<StoredComic> _sortedStoredComics() {
    final result = [..._storedComics];
    result.sort((a, b) {
      if (_storageSort == 'Título')
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (_storageSort == 'Recentes')
        return b.modifiedAt.compareTo(a.modifiedAt);
      final aRead = _comicIsRead(a);
      final bRead = _comicIsRead(b);
      if (aRead != bRead) return aRead ? -1 : 1;
      return b.bytes.compareTo(a.bytes);
    });
    return result;
  }

  Future<void> _openReader(
    Comic comic,
    ComicChapter chapter, {
    int initialPage = 0,
    String? sourceId,
  }) async {
    final folderId = comic.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final chapterFolderId =
        chapter.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final pages = await widget.archiveService.getOrCreatePages(comic, chapter);

    if (pages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Falha ao extrair as páginas. Formato não suportado ou erro de rede.')),
        );
      }
      return;
    }

    await _historyStore.save({
      'comicId': comic.id,
      'comicTitle': comic.title,
      'chapterId': chapter.id,
      'chapterTitle': chapter.title,
      'sourceId': sourceId,
      'sourceName': _sourceName(sourceId) ??
          (comic.sourceNames.isEmpty ? '' : comic.sourceNames.first),
      'page': initialPage,
      'totalPages': pages.length,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await _storageManager.recordChapter(
      folderId: folderId,
      comicTitle: comic.title,
      chapterId: chapterFolderId,
      completed: initialPage >= pages.length - 1,
    );

    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ComicReaderPage(
          comic: comic,
          chapter: chapter,
          pagePaths: pages,
          initialPage: initialPage,
          progressStore: ReadingHistoryProgressAdapter(
            _historyStore,
            extraData: {
              'sourceId': sourceId,
              'sourceName': _sourceName(sourceId) ??
                  (comic.sourceNames.isEmpty ? '' : comic.sourceNames.first),
            },
            onSave: (progress) async {
              await _storageManager.recordChapter(
                folderId: folderId,
                comicTitle: comic.title,
                chapterId: chapterFolderId,
                completed: progress.page >= progress.totalPages - 1,
              );
            },
          ),
        ),
      ),
    );

    _loadProgress();
    _loadStorageUsage();
  }

  String? _sourceName(String? id) {
    return _sourceConfigs.where((config) => config.id == id).firstOrNull?.name;
  }

  String? _sourceIdForComic(Comic comic) {
    return _activeSourceId;
  }

  Future<void> _resume(Map<String, dynamic> item) async {
    final sourceName = item['sourceName'] as String?;
    final sourceId = item['sourceId'] as String? ?? _activeSourceId ?? '';
    final comic = Comic(
      id: item['comicId'],
      title: item['comicTitle'],
      sourceNames:
          sourceName == null || sourceName.isEmpty ? const [] : [sourceName],
    );
    final chapter = ComicChapter(
        id: item['chapterId'],
        comicId: item['comicId'],
        title: item['chapterTitle']);
    await _openReader(comic, chapter,
        initialPage: item['page'],
        sourceId: sourceId.isEmpty ? null : sourceId);
  }

  void _openChapters(Comic comic) {
    final sourceId = _sourceIdForComic(comic);
    final source = _activeSource;
    if (!source.supportsChapters) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(source.chaptersUnavailableMessage ??
                'Leitura indisponível para esta fonte.')),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ComicChaptersPage(
          comic: comic,
          source: source,
          onReadChapter: (chapter) =>
              _openReader(comic, chapter, sourceId: sourceId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = const [
      NavigationDestination(
          icon: Icon(Icons.library_books_outlined),
          selectedIcon: Icon(Icons.library_books),
          label: 'Biblioteca'),
      NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'HQs'),
      NavigationDestination(
          icon: Icon(Icons.favorite_outline),
          selectedIcon: Icon(Icons.favorite),
          label: 'Favoritos'),
      NavigationDestination(
          icon: Icon(Icons.more_horiz),
          selectedIcon: Icon(Icons.more_horiz),
          label: 'Mais'),
    ];
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        return Row(children: [
          if (!compact) ...[
            NavigationRail(
              selectedIndex: _selectedTab,
              onDestinationSelected: (index) =>
                  setState(() => _selectedTab = index),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.library_books_outlined),
                  selectedIcon: Icon(Icons.library_books),
                  label: Text('Biblioteca'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: Text('HQs'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.favorite_outline),
                  selectedIcon: Icon(Icons.favorite),
                  label: Text('Favoritos'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.storage_outlined),
                  selectedIcon: Icon(Icons.storage),
                  label: Text('Armazenamento'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.folder_copy_outlined),
                  selectedIcon: Icon(Icons.folder_copy),
                  label: Text('Coleções'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.backup_outlined),
                  selectedIcon: Icon(Icons.backup),
                  label: Text('Backup'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.language_outlined),
                  selectedIcon: Icon(Icons.language),
                  label: Text('Fontes'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: _selectedTab == 0
                ? _LibraryView(
                    history: _history,
                    filter: _historyFilter,
                    sort: _historySort,
                    weeklyGoal: _weeklyGoal,
                    completedChapters: _completedChapters(),
                    pagesReadThisWeek: _pagesReadThisWeek(),
                    onFilterChanged: (value) =>
                        setState(() => _historyFilter = value),
                    onSortChanged: (value) =>
                        setState(() => _historySort = value),
                    onWeeklyGoalChanged: _setWeeklyGoal,
                    onContinue: _resume,
                    onBrowse: () => setState(() => _selectedTab = 1),
                  )
                : _selectedTab == 2
                    ? _FavoritesView(
                        favorites: _favorites,
                        onOpenComic: _openChapters,
                        onRemove: _toggleFavorite,
                      )
                    : _selectedTab == 3
                        ? _StorageView(
                            usedBytes: _storageBytes,
                            comics: _sortedStoredComics(),
                            sort: _storageSort,
                            onSortChanged: (value) =>
                                setState(() => _storageSort = value),
                            isRead: _comicIsRead,
                            selectedIds: _selectedStoredComicIds,
                            onSelectionChanged: (comic, selected) =>
                                setState(() {
                              if (selected) {
                                _selectedStoredComicIds.add(comic.id);
                              } else {
                                _selectedStoredComicIds.remove(comic.id);
                              }
                            }),
                            onDeleteSelected: _deleteSelectedStoredComics,
                            onRefresh: _loadStorageUsage,
                            onDeleteComic: _deleteStoredComic,
                            onDeleteChapter: _deleteStoredChapter,
                            onClear: _clearCache,
                          )
                        : _selectedTab == 4
                            ? _CollectionsView(
                                collections: _collections,
                                onCreate: _createCollection,
                                onDelete: (name) async {
                                  await _collectionStore.delete(name);
                                  await _loadCollections();
                                },
                                onOpenComic: _openChapters,
                                onRemoveComic: (name, comic) async {
                                  await _collectionStore.toggleComic(
                                      name, comic);
                                  await _loadCollections();
                                },
                              )
                            : _selectedTab == 5
                                ? _BackupView(
                                    onExport: () =>
                                        _backupAction(restore: false),
                                    onRestore: () =>
                                        _backupAction(restore: true),
                                  )
                                : _selectedTab == 6
                                    ? _CatalogSourcesView(
                                        configs: _sourceConfigs,
                                        activeId: _activeSourceId,
                                        onSelect: _selectSource,
                                        onAdd: _addSource,
                                        onRemove: _removeSource,
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                16, 12, 16, 0),
                                            child: Row(children: [
                                              Expanded(
                                                child: DropdownButtonFormField<
                                                    String>(
                                                  key:
                                                      ValueKey(_activeSourceId),
                                                  initialValue: _activeSourceId,
                                                  decoration:
                                                      const InputDecoration(
                                                    labelText: 'Catálogo ativo',
                                                    border:
                                                        OutlineInputBorder(),
                                                    prefixIcon:
                                                        Icon(Icons.language),
                                                  ),
                                                  isExpanded: true,
                                                  items: _sourceConfigs
                                                      .map((config) =>
                                                          DropdownMenuItem(
                                                            value: config.id,
                                                            child: Text(
                                                                config.name,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis),
                                                          ))
                                                      .toList(),
                                                  onChanged: (id) {
                                                    final config =
                                                        _sourceConfigs
                                                            .where((item) =>
                                                                item.id == id)
                                                            .firstOrNull;
                                                    if (config != null)
                                                      _selectSource(config);
                                                  },
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Gerenciar fontes',
                                                onPressed: () => setState(
                                                    () => _selectedTab = 6),
                                                icon:
                                                    const Icon(Icons.add_link),
                                              ),
                                            ]),
                                          ),
                                          if (_categories.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      16, 12, 16, 0),
                                              child: DropdownButtonFormField<
                                                  String>(
                                                key: ValueKey(
                                                    'category-$_activeSourceId'),
                                                decoration:
                                                    const InputDecoration(
                                                  labelText:
                                                      'Heróis / Categorias',
                                                  border: OutlineInputBorder(),
                                                ),
                                                initialValue: _selectedCategory,
                                                isExpanded: true,
                                                items: [
                                                  const DropdownMenuItem(
                                                      value: null,
                                                      child: Text(
                                                          '🏠 Início (Últimas Adicionadas)')),
                                                  ..._categories.map((c) =>
                                                      DropdownMenuItem(
                                                          value: c,
                                                          child: Text(c)))
                                                ],
                                                onChanged: (val) {
                                                  _selectedCategory = val;
                                                  _loadComics(); // Recarrega automaticamente ao escolher
                                                },
                                              ),
                                            ),
                                          Expanded(
                                            child: Column(children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        16, 12, 16, 0),
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: DropdownButton<String>(
                                                    value: _catalogFilter,
                                                    items: const [
                                                      DropdownMenuItem(
                                                          value: 'Todas',
                                                          child: Text(
                                                              'Todas as HQs')),
                                                      DropdownMenuItem(
                                                          value: 'Favoritos',
                                                          child: Text(
                                                              'Favoritos')),
                                                      DropdownMenuItem(
                                                          value: 'Em andamento',
                                                          child: Text(
                                                              'Em andamento')),
                                                      DropdownMenuItem(
                                                          value: 'Lidas',
                                                          child: Text('Lidas')),
                                                    ],
                                                    onChanged: (value) {
                                                      if (value != null)
                                                        setState(() =>
                                                            _catalogFilter =
                                                                value);
                                                    },
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                  child: FutureBuilder<
                                                      List<Comic>>(
                                                future: _comicsFuture,
                                                builder: (context, snapshot) {
                                                  if (snapshot
                                                          .connectionState !=
                                                      ConnectionState.done) {
                                                    return const Center(
                                                        child:
                                                            CircularProgressIndicator());
                                                  }
                                                  if (snapshot.hasError) {
                                                    return Center(
                                                      child: Text(
                                                          'Não foi possível carregar HQs: ${snapshot.error}'),
                                                    );
                                                  }
                                                  final comics = _filterComics(
                                                      _loadedComics);
                                                  return Column(children: [
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .fromLTRB(
                                                          16, 16, 16, 0),
                                                      child: TextField(
                                                        controller:
                                                            _searchController,
                                                        decoration:
                                                            InputDecoration(
                                                          labelText:
                                                              'Pesquisar no catálogo',
                                                          hintText:
                                                              'Título, descrição ou categoria',
                                                          prefixIcon:
                                                              const Icon(
                                                                  Icons.search),
                                                          suffixIcon:
                                                              IconButton(
                                                            tooltip:
                                                                'Limpar pesquisa',
                                                            icon: const Icon(
                                                                Icons.clear),
                                                            onPressed: () {
                                                              _searchController
                                                                  .clear();
                                                              _searchQuery = '';
                                                              _loadComics();
                                                            },
                                                          ),
                                                          border:
                                                              const OutlineInputBorder(),
                                                        ),
                                                        onChanged: (query) {
                                                          setState(() =>
                                                              _searchQuery =
                                                                  query);
                                                          _loadComics();
                                                        },
                                                      ),
                                                    ),
                                                    Expanded(
                                                        child: ComicGrid(
                                                      comics: comics,
                                                      onOpenComic:
                                                          _openChapters,
                                                      favoriteIds: _favorites
                                                          .map((comic) =>
                                                              comic.id)
                                                          .toSet(),
                                                      onToggleFavorite:
                                                          _toggleFavorite,
                                                      onAddToCollection:
                                                          _toggleComicInCollection,
                                                    )),
                                                    if (_hasMorePages)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                bottom: 16),
                                                        child: _isLoadingMore
                                                            ? const CircularProgressIndicator()
                                                            : OutlinedButton(
                                                                onPressed:
                                                                    _loadNextPage,
                                                                child: Text(
                                                                  'Carregar Página ${_currentPage + 1}',
                                                                ),
                                                              ),
                                                      ),
                                                  ]);
                                                },
                                              )),
                                            ]),
                                          ),
                                        ],
                                      ),
          ),
        ]);
      }),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 700
          ? NavigationBar(
              selectedIndex: _selectedTab > 2 ? 3 : _selectedTab,
              onDestinationSelected: (index) {
                if (index < 3) {
                  setState(() => _selectedTab = index);
                  return;
                }
                showModalBottomSheet<void>(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in const [
                          (3, 'Armazenamento', Icons.storage_outlined),
                          (4, 'Coleções', Icons.folder_copy_outlined),
                          (5, 'Backup', Icons.backup_outlined),
                          (6, 'Fontes', Icons.language_outlined),
                        ])
                          ListTile(
                            leading: Icon(entry.$3),
                            title: Text(entry.$2),
                            onTap: () {
                              Navigator.pop(context);
                              setState(() => _selectedTab = entry.$1);
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
              destinations: destinations,
            )
          : null,
    );
  }
}

class _LibraryView extends StatelessWidget {
  const _LibraryView({
    required this.history,
    required this.filter,
    required this.sort,
    required this.weeklyGoal,
    required this.completedChapters,
    required this.pagesReadThisWeek,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onWeeklyGoalChanged,
    required this.onContinue,
    required this.onBrowse,
  });

  final List<Map<String, dynamic>> history;
  final String filter;
  final String sort;
  final int weeklyGoal;
  final int completedChapters;
  final int pagesReadThisWeek;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<int> onWeeklyGoalChanged;
  final Function(Map<String, dynamic>) onContinue;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final series = history
        .map((item) => item['comicTitle'] as String)
        .toSet()
        .toList()
      ..sort();
    var visible = history.where((item) {
      final isRead = ReadingStatus().isChapterComplete(
        totalPages: item['totalPages'] as int? ?? 0,
        page: item['page'] as int? ?? 0,
      );
      final matchesFilter = filter == 'Todas' ||
          (filter == 'Lidas' && isRead) ||
          (filter == 'Em andamento' && !isRead) ||
          item['comicTitle'] == filter;
      return matchesFilter;
    }).toList();
    visible.sort((a, b) => sort == 'Título'
        ? (a['comicTitle'] as String).compareTo(b['comicTitle'] as String)
        : (DateTime.tryParse(b['updatedAt'] as String? ?? '') ?? DateTime(2000))
            .compareTo(DateTime.tryParse(a['updatedAt'] as String? ?? '') ??
                DateTime(2000)));
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Text('Biblioteca', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        const Text('O seu histórico de leitura.'),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Progresso de leitura',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                  '$completedChapters capítulos concluídos · $pagesReadThisWeek páginas registradas nos últimos 7 dias'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: LinearProgressIndicator(
                        value: (completedChapters / weeklyGoal)
                            .clamp(0, 1)
                            .toDouble())),
                const SizedBox(width: 12),
                Text('$completedChapters / $weeklyGoal capítulos'),
              ]),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final controller =
                        TextEditingController(text: '$weeklyGoal');
                    final value = await showDialog<int>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Meta semanal'),
                        content: TextField(
                            controller: controller,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Capítulos por semana')),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar')),
                          FilledButton(
                              onPressed: () => Navigator.pop(
                                  context, int.tryParse(controller.text)),
                              child: const Text('Salvar')),
                        ],
                      ),
                    );
                    if (value != null && value > 0)
                      onWeeklyGoalChanged(value.clamp(1, 100).toInt());
                  },
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Definir meta'),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            flex: 3,
            child: DropdownButton<String>(
              isExpanded: true,
              value: filter,
              items: [
                const DropdownMenuItem(
                    value: 'Todas', child: Text('Todas as séries')),
                const DropdownMenuItem(
                    value: 'Lidas', child: Text('Concluídas')),
                const DropdownMenuItem(
                    value: 'Em andamento', child: Text('Em andamento')),
                ...series.map((title) => DropdownMenuItem(
                    value: title,
                    child: Text(title, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (value) {
                if (value != null) onFilterChanged(value);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownButton<String>(
              isExpanded: true,
              value: sort,
              items: const [
                DropdownMenuItem(
                    value: 'Recentes', child: Text('Mais recentes')),
                DropdownMenuItem(value: 'Título', child: Text('Por título')),
              ],
              onChanged: (value) {
                if (value != null) onSortChanged(value);
              },
            ),
          ),
        ]),
        if (history.isEmpty)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: const CircleAvatar(child: Icon(Icons.menu_book)),
              title: const Text('A sua leitura aparecerá aqui'),
              subtitle:
                  const Text('Abra uma HQ e escolha um capítulo para começar.'),
              trailing: FilledButton(
                onPressed: onBrowse,
                child: const Text('Ver HQs'),
              ),
            ),
          )
        else
          ...visible.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(20),
                  leading: const CircleAvatar(child: Icon(Icons.bookmark)),
                  title: Text(item['comicTitle']),
                  subtitle: Text(
                    '${item['chapterTitle']} · página ${item['page'] + 1} de ${item['totalPages']}',
                  ),
                  trailing: FilledButton.icon(
                    onPressed: () => onContinue(item),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Continuar'),
                  ),
                ),
              )),
      ],
    );
  }
}

class _FavoritesView extends StatelessWidget {
  const _FavoritesView(
      {required this.favorites,
      required this.onOpenComic,
      required this.onRemove});
  final List<Comic> favorites;
  final ValueChanged<Comic> onOpenComic;
  final ValueChanged<Comic> onRemove;

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(28),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Favoritos',
                style: Theme.of(context).textTheme.headlineLarge),
          ),
        ),
        Expanded(
          child: favorites.isEmpty
              ? const Center(child: Text('Ainda não há HQs favoritas.'))
              : ListView.builder(
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final comic = favorites[index];
                    return ListTile(
                      leading: const Icon(Icons.favorite),
                      title: Text(comic.title),
                      onTap: () => onOpenComic(comic),
                      trailing: IconButton(
                        tooltip: 'Remover dos favoritos',
                        icon: const Icon(Icons.favorite),
                        onPressed: () => onRemove(comic),
                      ),
                    );
                  },
                ),
        ),
      ]);
}

class _CollectionsView extends StatelessWidget {
  const _CollectionsView(
      {required this.collections,
      required this.onCreate,
      required this.onDelete,
      required this.onOpenComic,
      required this.onRemoveComic});
  final List<ComicCollection> collections;
  final VoidCallback onCreate;
  final ValueChanged<String> onDelete;
  final ValueChanged<Comic> onOpenComic;
  final void Function(String name, Comic comic) onRemoveComic;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Row(children: [
            Expanded(
                child: Text('Coleções',
                    style: Theme.of(context).textTheme.headlineLarge)),
            FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.create_new_folder),
                label: const Text('Nova coleção')),
          ]),
          const SizedBox(height: 16),
          if (collections.isEmpty)
            const Text(
                'Crie coleções para agrupar HQs, por exemplo “Para ler” ou “Favoritas”.'),
          for (final collection in collections)
            Card(
              child: ExpansionTile(
                title: Text(collection.name),
                subtitle: Text('${collection.comics.length} HQ(s)'),
                trailing: IconButton(
                  tooltip: 'Excluir coleção',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onDelete(collection.name),
                ),
                children: collection.comics.isEmpty
                    ? const [
                        ListTile(
                            title: Text(
                                'Coleção vazia. Adicione HQs pelo botão de pasta no catálogo.'))
                      ]
                    : collection.comics
                        .map((comic) => ListTile(
                              leading: const Icon(Icons.menu_book),
                              title: Text(comic.title),
                              onTap: () => onOpenComic(comic),
                              trailing: IconButton(
                                tooltip: 'Remover da coleção',
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () =>
                                    onRemoveComic(collection.name, comic),
                              ),
                            ))
                        .toList(),
              ),
            ),
        ],
      );
}

class _BackupView extends StatelessWidget {
  const _BackupView({required this.onExport, required this.onRestore});
  final VoidCallback onExport;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Backup local',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          const Text(
              'Salva ou restaura histórico, favoritos, coleções, preferências de leitura e meta. O arquivo fica na pasta Documentos do app.'),
          const SizedBox(height: 20),
          Wrap(spacing: 12, children: [
            FilledButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.save_alt),
                label: const Text('Exportar backup')),
            OutlinedButton.icon(
                onPressed: onRestore,
                icon: const Icon(Icons.settings_backup_restore),
                label: const Text('Restaurar backup local')),
          ]),
        ]),
      );
}

class _CatalogSourcesView extends StatelessWidget {
  const _CatalogSourcesView({
    required this.configs,
    required this.activeId,
    required this.onSelect,
    required this.onAdd,
    required this.onRemove,
  });

  final List<CatalogSourceConfig> configs;
  final String? activeId;
  final ValueChanged<CatalogSourceConfig> onSelect;
  final Future<void> Function(String url) onAdd;
  final Future<void> Function(CatalogSourceConfig config) onRemove;

  Future<void> _showAddDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar catálogo'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL pública do site',
                hintText: 'https://exemplo.com',
              ),
              onSubmitted: (_) => Navigator.pop(context, controller.text),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Adicionar')),
        ],
      ),
    );
    if (result == null) return;
    try {
      await onAdd(result);
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('URL inválida: ${error.message}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Fontes de catálogo',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          const Text(
              'Cadastre vários endereços de blogs e escolha um para usar. A aba HQs carrega somente o catálogo selecionado.'),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _showAddDialog(context),
              icon: const Icon(Icons.add_link),
              label: const Text('Adicionar link'),
            ),
          ),
          const SizedBox(height: 12),
          for (final config in configs)
            Card(
              child: ListTile(
                leading: Icon(config.id == activeId
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: Text(config.name),
                subtitle: Text(config.baseUrl),
                onTap: () => onSelect(config),
                trailing: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (config.id == activeId)
                      const Chip(label: Text('Em uso'))
                    else
                      TextButton(
                          onPressed: () => onSelect(config),
                          child: const Text('Usar')),
                    if (configs.length > 1)
                      IconButton(
                        tooltip: 'Remover link',
                        onPressed: () => onRemove(config),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
}

class _StorageView extends StatelessWidget {
  const _StorageView(
      {required this.usedBytes,
      required this.comics,
      required this.sort,
      required this.onSortChanged,
      required this.isRead,
      required this.selectedIds,
      required this.onSelectionChanged,
      required this.onDeleteSelected,
      required this.onRefresh,
      required this.onDeleteComic,
      required this.onDeleteChapter,
      required this.onClear});
  final int? usedBytes;
  final List<StoredComic> comics;
  final String sort;
  final ValueChanged<String> onSortChanged;
  final bool Function(StoredComic) isRead;
  final Set<String> selectedIds;
  final void Function(StoredComic comic, bool selected) onSelectionChanged;
  final VoidCallback onDeleteSelected;
  final VoidCallback onRefresh;
  final ValueChanged<StoredComic> onDeleteComic;
  final void Function(StoredComic, StoredChapter) onDeleteChapter;
  final VoidCallback onClear;

  String _formatBytes(int? value) {
    if (value == null) return 'Calculando…';
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final readComics = comics.where(isRead).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Armazenamento', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text('Espaço usado: ${_formatBytes(usedBytes)}'),
        const SizedBox(height: 12),
        Wrap(spacing: 12, children: [
          OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar')),
          FilledButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Limpar todo o cache')),
        ]),
        if (selectedIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FilledButton.tonalIcon(
              onPressed: onDeleteSelected,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(
                  'Excluir ${selectedIds.length} · liberar ${_formatBytes(comics.where((comic) => selectedIds.contains(comic.id)).fold<int>(0, (sum, comic) => sum + comic.bytes))}'),
            ),
          ),
        const SizedBox(height: 24),
        Text('HQs baixadas', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('As lidas aparecem primeiro como sugestão para liberar espaço.'),
        DropdownButton<String>(
          value: sort,
          items: const [
            DropdownMenuItem(
                value: 'Espaço', child: Text('Ordenar: maior espaço')),
            DropdownMenuItem(
                value: 'Recentes', child: Text('Ordenar: mais recentes')),
            DropdownMenuItem(value: 'Título', child: Text('Ordenar: título')),
          ],
          onChanged: (value) {
            if (value != null) onSortChanged(value);
          },
        ),
        const SizedBox(height: 8),
        Expanded(
          child: comics.isEmpty
              ? const Center(child: Text('Ainda não há HQs armazenadas.'))
              : ListView.builder(
                  itemCount: comics.length,
                  itemBuilder: (context, index) {
                    final comic = comics[index];
                    final read = isRead(comic);
                    return Card(
                      child: ExpansionTile(
                        leading: Checkbox(
                          value: selectedIds.contains(comic.id),
                          onChanged: (selected) =>
                              onSelectionChanged(comic, selected ?? false),
                        ),
                        title: Text(comic.title),
                        subtitle: Text(
                            '${read ? 'Lida · sugestão para excluir' : 'Não concluída'} · ${comic.chapterCount} capítulos · ${_formatBytes(comic.bytes)}'),
                        trailing: IconButton(
                          tooltip: 'Excluir arquivos desta HQ',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => onDeleteComic(comic),
                        ),
                        children: comic.chapters
                            .map((chapter) => ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.article_outlined),
                                  title: Text(chapter.id.replaceAll('_', ' ')),
                                  subtitle: Text(_formatBytes(chapter.bytes)),
                                  trailing: IconButton(
                                    tooltip: 'Remover capítulo',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () =>
                                        onDeleteChapter(comic, chapter),
                                  ),
                                ))
                            .toList(),
                      ),
                    );
                  },
                ),
        ),
        if (readComics.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child:
                Text('${readComics.length} HQ(s) lida(s) podem ser removidas.'),
          ),
      ]),
    );
  }
}
