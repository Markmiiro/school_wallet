// Opens a link outside the app (WhatsApp, the mail app). On the web it
// asks the browser; elsewhere it reports that it could not, and the
// caller shows the contact details instead.

export 'open_link_stub.dart' if (dart.library.js_interop) 'open_link_web.dart';
