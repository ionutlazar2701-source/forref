import 'package:flutter/widgets.dart';
import 'package:referee_phone/app.dart';
import 'package:referee_phone/infrastructure/database/local_match_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RefereeApp(database: LocalMatchDatabase()));
}
