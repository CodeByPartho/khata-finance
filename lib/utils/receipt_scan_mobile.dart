import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// On-device receipt scanning for Android and iOS. Uses ML Kit text
/// recognition, which runs fully on the device with no account and
/// no network. Returns the recognized text, or null when the user
/// cancels or nothing is recognized.
const bool isReceiptScanSupported = true;

Future<String?> scanReceipt() async {
  final ImagePicker picker = ImagePicker();
  final XFile? photo =
      await picker.pickImage(source: ImageSource.camera);
  if (photo == null) {
    return null;
  }
  final TextRecognizer recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final RecognizedText result =
        await recognizer.processImage(InputImage.fromFilePath(photo.path));
    final String text = result.text.trim();
    return text.isEmpty ? null : text;
  } finally {
    await recognizer.close();
  }
}
