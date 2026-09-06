import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String uuidV4() => _uuid.v4();

String uuidV7() => _uuid.v7();

String uuidV5(String namespace, String name) => _uuid.v5(namespace, name);
