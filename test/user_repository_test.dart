import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import '../lib/src/features/users/data/users_repository.dart';



// ---- Mocks ----
class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}
class MockHttpsCallable extends Mock implements HttpsCallable {}
class MockHttpsCallableResult extends Mock implements HttpsCallableResult {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

// If your UsersRepository constructor is (db, functions, auth) use this.
// If yours is different, tweak the repo init line below.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore db;
  late MockFirebaseFunctions functions;
  late MockHttpsCallable callable;
  late MockHttpsCallableResult result;
  late MockFirebaseAuth auth;

  setUp(() {
    db = FakeFirebaseFirestore();
    functions = MockFirebaseFunctions();
    callable = MockHttpsCallable();
    result = MockHttpsCallableResult();
    auth = MockFirebaseAuth();

    when(() => functions.httpsCallable('createUserWithRole'))
        .thenReturn(callable);

    when(() => result.data).thenReturn({'uid': 'UID_123'});
    when(() => callable.call(any())).thenAnswer((_) async => result);
    when(() => auth.sendPasswordResetEmail(email: any(named: 'email')))
        .thenAnswer((_) async {});
  });

  test('createUser sends payload to callable and sends reset email', () async {
    // If your repo expects (db, functions, auth):
    final repo = UsersRepository(db, functions, auth);

    final uid = await repo.createUser(
      displayName: 'Jane Doe',
      email: 'jane@example.com',
      role: 'store',
    );

    expect(uid, 'UID_123');

    verify(() => callable.call({
      'displayName': 'Jane Doe',
      'email': 'jane@example.com',
      'role': 'store',
    })).called(1);

    verify(() => auth.sendPasswordResetEmail(email: 'jane@example.com'))
        .called(1);
  });
}
