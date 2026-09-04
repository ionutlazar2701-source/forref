import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String clientId() => _uuid.v4();
