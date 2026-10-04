import 'package:flutter_test/flutter_test.dart';
import 'package:ceylora_app/widgets/ui/ui.dart';

void main() {
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

    // Under the Flutter test runner (not web, not Android) ApiService.baseUrl resolves to
    // "http://localhost:5220/api", so the API origin used here is "http://localhost:5220".
    test('prefixes a relative "/uploads/..." path with the API origin', () {
      expect(
        resolveImageUrl('/uploads/vehicle-photos/1.jpg'),
        'http://localhost:5220/uploads/vehicle-photos/1.jpg',
      );
    });

    test('adds the missing leading slash for a relative path that lacks one', () {
      expect(
        resolveImageUrl('uploads/vehicle-photos/1.jpg'),
        'http://localhost:5220/uploads/vehicle-photos/1.jpg',
      );
    });
  });
}
