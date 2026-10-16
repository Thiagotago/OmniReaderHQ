import 'catalog_entry.dart';

abstract interface class CatalogRepository {
  List<CatalogEntry> listEntries();
}
