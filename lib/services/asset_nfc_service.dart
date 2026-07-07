import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';

class AssetNfcService {
  static const String ndefPrefix = 'YM:ASSET:';

  Future<bool> isAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  String bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  List<int>? _extractIdentifier(NfcTag tag) {
    final data = tag.data;
    for (final key in ['nfca', 'mifare', 'nfcb', 'nfcf', 'ndef']) {
      final section = data[key];
      if (section is Map && section['identifier'] is List) {
        return List<int>.from(section['identifier'] as List);
      }
    }
    return null;
  }

  String? parseSerialFromNdef(String? text) {
    if (text == null || text.isEmpty) return null;
    final trimmed = text.trim();
    if (trimmed.startsWith(ndefPrefix)) {
      return trimmed.substring(ndefPrefix.length).trim();
    }
    return trimmed;
  }

  String? _decodeNdefText(NdefMessage message) {
    for (final record in message.records) {
      if (record.typeNameFormat != NdefTypeNameFormat.nfcWellknown) continue;
      if (!_isTextRecord(record)) continue;
      final payload = record.payload;
      if (payload.isEmpty) continue;
      final status = payload[0];
      final langLen = status & 0x3F;
      final textBytes = payload.sublist(1 + langLen);
      return utf8.decode(textBytes, allowMalformed: true);
    }
    return null;
  }

  bool _isTextRecord(NdefRecord record) {
    if (record.type.length != 1) return false;
    return record.type[0] == 0x54;
  }

  Future<String?> readTagUid({Duration timeout = const Duration(seconds: 30)}) async {
    String? uid;
    final completer = _CompleterGuard<String?>();

    await NfcManager.instance.startSession(
      onDiscovered: (tag) async {
        try {
          final id = _extractIdentifier(tag);
          if (id != null) {
            uid = bytesToHex(id);
            completer.complete(uid);
          }
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );

    return completer.wait(timeout);
  }

  Future<AssetNfcReadResult?> readTag({Duration timeout = const Duration(seconds: 30)}) async {
    AssetNfcReadResult? result;
    final completer = _CompleterGuard<AssetNfcReadResult?>();

    await NfcManager.instance.startSession(
      onDiscovered: (tag) async {
        try {
          final id = _extractIdentifier(tag);
          final uid = id != null ? bytesToHex(id) : null;
          String? ndefText;
          String? serialNumber;

          final ndef = Ndef.from(tag);
          if (ndef != null) {
            final cached = ndef.cachedMessage;
            if (cached != null) {
              ndefText = _decodeNdefText(cached);
              serialNumber = parseSerialFromNdef(ndefText);
            }
          }

          result = AssetNfcReadResult(
            tagUid: uid,
            ndefText: ndefText,
            serialNumber: serialNumber,
          );
          completer.complete(result);
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );

    return completer.wait(timeout);
  }

  Future<bool> writeSerialToTag(String serialNumber, {Duration timeout = const Duration(seconds: 30)}) async {
    final payload = '$ndefPrefix$serialNumber';
    final completer = _CompleterGuard<bool>();

    await NfcManager.instance.startSession(
      onDiscovered: (tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            completer.complete(false);
            return;
          }
          if (!ndef.isWritable) {
            completer.complete(false);
            return;
          }

          final message = NdefMessage([
            NdefRecord.createText(payload),
          ]);
          await ndef.write(message);
          completer.complete(true);
        } catch (_) {
          completer.complete(false);
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );

    return await completer.wait(timeout) ?? false;
  }

  Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }
}

class AssetNfcReadResult {
  final String? tagUid;
  final String? ndefText;
  final String? serialNumber;

  AssetNfcReadResult({this.tagUid, this.ndefText, this.serialNumber});
}

class _CompleterGuard<T> {
  T? _value;
  bool _done = false;

  void complete(T value) {
    if (_done) return;
    _done = true;
    _value = value;
  }

  Future<T?> wait(Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (!_done && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return _value;
  }
}
