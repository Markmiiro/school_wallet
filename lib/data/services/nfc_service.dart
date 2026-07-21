// Reads a physical NFC card's UID using nfc_manager 3.5.1.
// Written against the confirmed installed API:
//   - NfcManager.instance.isAvailable() -> Future<bool>
//   - startSession({onDiscovered, pollingOptions})
//   - platform tag classes (NfcA etc.) expose Uint8List identifier
//
// The identifier bytes are converted to an uppercase hex string with
// no separators — e.g. [0x04, 0xA2, 0x1B] -> "04A21B". This hex string
// is what we send to the backend as tag_uid.

import 'dart:async';
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

class NfcService {
  /// Whether this device has NFC available and enabled.
  Future<bool> isAvailable() {
    return NfcManager.instance.isAvailable();
  }

  /// Starts an NFC session and waits for a single card tap, returning
  /// its UID as an uppercase hex string. Times out after [timeout].
  Future<String> readCardUid({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final available = await isAvailable();
    if (!available) {
      throw Exception('NFC is not available or is turned off on this device.');
    }

    final completer = Completer<String>();

    NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443, // MIFARE / DESFire / most payment cards
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (NfcTag tag) async {
        try {
          final uid = _extractUid(tag);
          if (uid == null) {
            await NfcManager.instance.stopSession(
              errorMessage: 'Could not read this card.',
            );
            if (!completer.isCompleted) {
              completer.completeError(
                Exception('This card did not expose a readable UID.'),
              );
            }
            return;
          }
          await NfcManager.instance.stopSession();
          if (!completer.isCompleted) completer.complete(uid);
        } catch (e) {
          await NfcManager.instance.stopSession(errorMessage: 'Read failed.');
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
    );

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        NfcManager.instance.stopSession();
        throw Exception('No card detected. Please try again.');
      },
    );
  }

  /// Cancels any in-progress NFC session (e.g. when leaving the screen).
  Future<void> cancel() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // Safe to ignore — there may be no active session.
    }
  }

  /// Tries each Android platform tag type in turn to find one that
  /// exposes an identifier, then returns it as uppercase hex.
  String? _extractUid(NfcTag tag) {
    Uint8List? identifier;

    identifier ??= NfcA.from(tag)?.identifier;
    identifier ??= MifareClassic.from(tag)?.identifier;
    identifier ??= MifareUltralight.from(tag)?.identifier;
    identifier ??= IsoDep.from(tag)?.identifier;
    identifier ??= NfcF.from(tag)?.identifier;
    identifier ??= NfcV.from(tag)?.identifier;

    if (identifier == null || identifier.isEmpty) return null;

    return identifier
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }
}