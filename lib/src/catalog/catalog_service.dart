import 'catalog_entry.dart';
import 'catalog_repository.dart';

class EmptyCatalogRepository implements CatalogRepository {
  @override
  List<CatalogEntry> listEntries() {
    return const [];
  }
}
