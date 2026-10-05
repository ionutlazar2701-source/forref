import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';
import 'package:referee_phone/infrastructure/match_memory/uuid_record_identity_generator.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';

/// Composition root for the new Match Application boundary.
///
/// Opens a dedicated SQLite file under [storageRoot]. This is physically and
/// logically separate from legacy [LocalMatchDatabase] (Drift).
///
/// Instantiate when wiring a cut-over flow. Do not attach to legacy
/// [MatchSession] or dual-write paths until that flow is explicitly migrated.
final class MatchApplicationComposition {
  MatchApplicationComposition._({
    required this.boundary,
    required this.databaseFile,
  });

  final MatchApplicationBoundary boundary;
  final File databaseFile;

  /// Opens the durable Match Memory store at `{storageRoot}/forref_match_memory/match_memory.sqlite`.
  static Future<MatchApplicationComposition> open({
    required Directory storageRoot,
  }) async {
    final memoryDir = Directory('${storageRoot.path}/forref_match_memory');
    if (!memoryDir.existsSync()) {
      memoryDir.createSync(recursive: true);
    }
    final databaseFile = File('${memoryDir.path}/match_memory.sqlite');
    final boundary = MatchApplicationBoundary(
      store: SqliteDurableMatchStore.open(databaseFile),
      recordBuilder: AuthoritativeRecordBuilder(
        identityGenerator: const UuidRecordIdentityGenerator(),
      ),
    );
    return MatchApplicationComposition._(
      boundary: boundary,
      databaseFile: databaseFile,
    );
  }

  Future<void> close() => boundary.close();
}
