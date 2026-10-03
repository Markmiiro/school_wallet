// Web: a new tab for https links (wa.me opens WhatsApp or WhatsApp Web);
// mailto in the same tab, which hands over to the mail app without
// leaving a blank tab behind.

import 'dart:js_interop';

@JS('window.open')
external JSObject? _open(JSString url, JSString target);

Future<bool> openLink(Uri uri) async {
  try {
    _open(uri.toString().toJS, (uri.scheme == 'mailto' ? '_self' : '_blank').toJS);
    return true;
  } catch (_) {
    return false;
  }
}
