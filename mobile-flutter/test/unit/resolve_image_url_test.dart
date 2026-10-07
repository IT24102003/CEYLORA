import 'package:flutter_test/flutter_test.dart';
import 'package:ceylora_app/services/api_service.dart';
import 'package:ceylora_app/widgets/ui/ui.dart';

void main() {
  // The API origin depends on how the app is built (local backend, Android emulator or the
  // deployed Railway backend), so the tests derive the expected origin from the same
  // ApiService.baseUrl that resolveImageUrl uses instead of hard-coding localhost.
  final origin = ApiService.baseUrl.replaceAll('/api', '');

  group('resolveImageUrl', () {
    test('returns null for null, empty or whitespace-only input', () {
      expect(resolveImageUrl(null), isNull);
      expect(resolveImageUrl(''), isNull);
      expect(resolveImageUrl('   '), isNull);
    });

    test('leaves an already-absolute http(s) URL unchanged', () {
      expect(resolveImageUrl('https://cdn.example.com/a.jpg'), 'https://cdn.example.com/a.jpg');
      expect(resolveImageUrl('http://cdn.example.com/a.jpg'), 'http://cdn.example.com/a.jpg');
    });

    test('prefixes a relative "/uploads/..." path with the API origin', () {
      expect(
        resolveImageUrl('/uploads/vehicle-photos/1.jpg'),
        '$origin/uploads/vehicle-photos/1.jpg',
      );
    });

    test('adds the missing leading slash for a relative path that lacks one', () {
      expect(
        resolveImageUrl('uploads/vehicle-photos/1.jpg'),
        '$origin/uploads/vehicle-photos/1.jpg',
      );
    });
  });
}