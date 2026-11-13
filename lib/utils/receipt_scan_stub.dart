/// Stub used on web and desktop, where on-device receipt scanning
/// is not available.
const bool isReceiptScanSupported = false;

/// Always returns null on platforms without scanning support.
Future<String?> scanReceipt() async {
  return null;
}
