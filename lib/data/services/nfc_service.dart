// Reads a physical NFC card's UID using nfc_manager 4.2.1.
// Written against the confirmed installed v4 API:
//   - NfcManager.instance.checkAvailability() -> Future<NfcAvailability>
//   - startSession({pollingOptions, onDiscovered: void Function(NfcTag)})
//   - NfcTagAndroid.from(tag).id -> Uint8List UID (works for any card type)
//
// The id bytes are converted to an uppercase hex string with no
// separators — e.g. [0x04, 0xA2, 0x1B] -> "04A21B". This hex string is
// what we send to the backend as tag_uid.

import 'dart:async';
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

class NfcService {
  /// Whether this device has NFC available and enabled.
  Future<bool> isAvailable() async {
    final availability = await NfcManager.instance.checkAvailability();
    return availability == NfcAvailability.enabled;
  }

  /// Starts an NFC session and waits for a single card tap, returning
  /// its UID as an uppercase hex string. Times out after [timeout].
  Future<String> readCardUid({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final availability = await NfcManager.instance.checkAvailability();
    if (availability != NfcAvailability.enabled) {
      throw Exception(
        availability == NfcAvailability.disabled
            ? 'NFC is turned off. Please enable it in your phone settings.'
            : 'NFC is not supported on this device.',
      );
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
          final androidTag = NfcTagAndroid.from(tag);
          if (androidTag == null || androidTag.id.isEmpty) {
            await NfcManager.instance.stopSession(
              errorMessageIos: 'Could not read this card.',
            );
            if (!completer.isCompleted) {
              completer.completeError(
                Exception('This card did not expose a readable UID.'),
              );
            }
            return;
          }
          final uid = _toHex(androidTag.id);
          await NfcManager.instance.stopSession();
          if (!completer.isCompleted) completer.complete(uid);
        } catch (e) {
          await NfcManager.instance.stopSession(errorMessageIos: 'Read failed.');
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

  String _toHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }
}