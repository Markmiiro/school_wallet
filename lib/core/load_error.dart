// What to tell the parent when a screen could not load.
//
// Services throw Exception('…') with words meant for the parent; the
// network layer throws its own (ClientException, TimeoutException,
// "Failed to fetch" on the web), which mean nothing to them.

import 'dart:async';
import 'package:http/http.dart' as http;

const couldNotReachServer =
    'Could not reach the server. Check your connection and try again.';

String loadErrorText(Object error) {
  if (error is TimeoutException || error is http.ClientException) {
    return couldNotReachServer;
  }
  final text = error.toString().replaceFirst('Exception: ', '').trim();
  if (text.isEmpty ||
      text.contains('Failed to fetch') ||
      text.contains('SocketException') ||
      text.contains('XMLHttpRequest')) {
    return couldNotReachServer;
  }
  return text;
}
