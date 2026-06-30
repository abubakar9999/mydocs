import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

/// Service responsible for handling biometric authentication 
/// (Face ID, Touch ID, Fingerprint) for the SecureVault app.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if the device has biometric hardware and if any biometrics are enrolled.
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException {
      return false;
    }
  }

  /// Authenticates the user via biometrics.
  /// Returns [true] if authentication is successful, [false] otherwise.
  Future<bool> authenticate({String reason = 'Unlock your SecureVault'}) async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true, // Force biometrics, fallback to PIN is handled by OS if not biometricOnly
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable) {
        // Biometrics are not available on this device
      } else if (e.code == auth_error.notEnrolled) {
        // User has not enrolled any biometrics on the device
      } else if (e.code == auth_error.lockedOut) {
        // Too many failed attempts
      }
      return false;
    }
  }

  /// Get available biometric types on the device (e.g. face, fingerprint, iris).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    }
  }
}
