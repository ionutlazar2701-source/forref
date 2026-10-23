import 'package:uuid/uuid.dart';

abstract interface class MobileCommandIdSource {
  String nextId();
}

final class UuidCommandIdSource implements MobileCommandIdSource {
  const UuidCommandIdSource();

  static const _uuid = Uuid();

  @override
  String nextId() => _uuid.v4();
}

final class SequenceCommandIdSource implements MobileCommandIdSource {
  SequenceCommandIdSource({this.prefix = 'id'});

  final String prefix;
  int _n = 0;

  @override
  String nextId() {
    _n += 1;
    return '$prefix-$_n';
  }
}
