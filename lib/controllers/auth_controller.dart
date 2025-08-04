import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

// Store this when sending OTP
final verificationIdProvider = StateProvider<String?>((ref) => null);

Future<void> sendOTP({
  required WidgetRef ref,
  required String phoneNumber,
  required void Function() onCodeSent,
  required void Function(String error) onFailed,
}) async {
  final auth = ref.read(firebaseAuthProvider);

  await auth.verifyPhoneNumber(
    phoneNumber: phoneNumber,
    verificationCompleted: (PhoneAuthCredential credential) async {
      // Optional: auto sign in
      await auth.signInWithCredential(credential);
    },
    verificationFailed: (FirebaseAuthException e) {
      onFailed(e.message ?? "Verification failed");
    },
    codeSent: (String verificationId, int? resendToken) {
      ref.read(verificationIdProvider.notifier).state = verificationId;
      onCodeSent();
    },
    codeAutoRetrievalTimeout: (String verificationId) {
      ref.read(verificationIdProvider.notifier).state = verificationId;
    },
  );
}

Future<void> verifyOTP({
  required WidgetRef ref,
  required String otp,
  required void Function() onSuccess,
  required void Function(String error) onFailed,
}) async {
  final auth = ref.read(firebaseAuthProvider);
  final verificationId = ref.read(verificationIdProvider);

  if (verificationId == null) {
    onFailed("Verification ID missing");
    return;
  }

  final credential = PhoneAuthProvider.credential(
    verificationId: verificationId,
    smsCode: otp,
  );

  try {
    await auth.signInWithCredential(credential);
    onSuccess();
  } catch (e) {
    onFailed("OTP verification failed");
  }
}
