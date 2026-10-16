import 'package:flutter_test/flutter_test.dart';

import 'package:omni_reader/src/access/access_policy.dart';

void main() {
  test('denies transfer without explicit authorization', () {
    final decision = const AccessPolicy().evaluate(userAuthorized: false);

    expect(decision.allowed, isFalse);
    expect(decision.reason, contains('autorização explícita'));
  });

  test('allows a future transfer only after explicit authorization', () {
    final decision = const AccessPolicy().evaluate(userAuthorized: true);

    expect(decision.allowed, isTrue);
    expect(decision.reason, isNull);
  });
}
