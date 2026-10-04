import 'package:flutter_test/flutter_test.dart';
import 'package:ceylora_app/widgets/registration_widgets.dart';

void main() {
  group('requiredField', () {
    test('returns the message when the value is null', () {
      expect(requiredField(null, 'Required.'), 'Required.');
    });

    test('returns the message when the value is empty or whitespace-only', () {
      expect(requiredField('', 'Required.'), 'Required.');
      expect(requiredField('   ', 'Required.'), 'Required.');
    });

    test('returns null (valid) once the value has real content', () {
      expect(requiredField('Toyota HiAce', 'Required.'), isNull);
      expect(requiredField('  Kandy  ', 'Required.'), isNull); // surrounding whitespace is fine
    });
  });
}
