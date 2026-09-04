import 'package:flutter/widgets.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.database,
    required this.locale,
    required super.child,
  });

  final LocalMatchDatabase database;
  final ValueNotifier<Locale?> locale;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.database != database || oldWidget.locale != locale;
}
