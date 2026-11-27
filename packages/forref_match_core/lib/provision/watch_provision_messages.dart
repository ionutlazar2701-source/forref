import 'watch_provision_v1.dart';

const String getWatchProvisionV1 = 'GET_WATCH_PROVISION_V1';
const String watchProvisionVerifiedV1 = 'WATCH_PROVISION_VERIFIED_V1';
const String activateWatchV1 = 'ACTIVATE_WATCH_V1';
const String watchActivatedV1 = 'WATCH_ACTIVATED_V1';

/// A transport acknowledgement without [readBack] is not a verified receipt.
WatchConfigVerifiedReceipt? verifiedReceiptFromMessage(
  Map<String, Object?> message,
) {
  if (message['type'] != watchProvisionVerifiedV1) return null;
  if (message['readBack'] != true) return null;
  if (message['generation'] != 1) return null;
  final hash = message['contentHash'];
  final writer = message['writerDeviceId'];
  if (hash is! String || hash.isEmpty || writer is! String || writer.isEmpty) {
    return null;
  }
  return WatchConfigVerifiedReceipt(
    contentHash: hash,
    writerDeviceId: writer,
    generation: 1,
    readBack: true,
  );
}

/// A lost activation response has no durable flag and must not be treated as done.
bool activationDurable(Map<String, Object?> message) {
  return message['type'] == watchActivatedV1 &&
      message['durable'] == true &&
      message['generation'] == 1;
}
