// Receipt scanning entry point. On Android and iOS this uses the
// on-device ML Kit text recognizer; on web and desktop it is not
// supported and scanReceipt returns null.
export 'receipt_scan_stub.dart'
    if (dart.library.io) 'receipt_scan_mobile.dart';
