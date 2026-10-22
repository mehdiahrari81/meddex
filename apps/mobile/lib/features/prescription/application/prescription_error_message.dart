import '../../../core/errors/app_error.dart';

String prescriptionErrorMessage(Object error) => switch (error) {
  PrescriptionServiceError(code: 'image_upload_interrupted') =>
    'The image upload was interrupted before it could finish. Your scan is saved. '
        'Keep both devices connected and the app open, then retry.',
  NetworkUnavailableError() =>
    'Cannot reach the app server. Keep the Mac and iPhone on the same Wi-Fi, '
        'keep the API running, and allow Local Network access for MediExplain in iPhone Settings.',
  RequestTimeoutError() =>
    'The server took too long to respond. Your scan is saved. After changing Wi-Fi, '
        'wait for both devices to reconnect to the same network, then retry.',
  AuthenticationExpiredError() =>
    'Your sign-in session has expired. Sign in again, then reopen your saved scan.',
  PrescriptionServiceError(code: 'cloud_limit_reached') =>
    'The cloud readers have reached their usage limits. Your scan is saved. Retry later or review the medicines manually.',
  PrescriptionServiceError(code: 'cloud_temporarily_unavailable') =>
    'Both cloud readers are temporarily unavailable. Your scan is saved; please retry shortly.',
  PrescriptionServiceError(code: 'gemini_limit_reached') =>
    'Gemini has reached its usage limit. Your text is saved. Retry later or review the medicines locally.',
  PrescriptionServiceError(code: 'gemini_request_timeout') =>
    'Gemini is taking too long to read this prescription. Your scan is saved. Retry later or enter the medicines manually.',
  PrescriptionServiceError(code: 'gemini_temporarily_busy') =>
    'Google\'s prescription reader is busy. Automatic recovery could not complete this scan. Your image is saved; please retry shortly.',
  PrescriptionServiceError(code: 'gemini_handwriting_unavailable') =>
    'Gemini could not read this prescription image. Your image is saved. Try a clearer, cropped photo or retry your saved scan.',
  PrescriptionServiceError(code: 'medicine_extraction_unverified') =>
    'The AI could not reliably match medicines to the recognized text. Review the extracted text for OCR mistakes and retry.',
  PrescriptionServiceError() || ServerError() =>
    'The medicine service is temporarily unavailable. Your scan is saved. Please retry.',
  RateLimitedError() => 'Too many requests. Wait a minute and retry.',
  ValidationError() =>
    'The recognized text could not be submitted. Review the text and retry with up to 10 pages.',
  _ =>
    'Could not process the medicine information. Review the extracted text and retry. Confirmed items cannot be overwritten.',
};
