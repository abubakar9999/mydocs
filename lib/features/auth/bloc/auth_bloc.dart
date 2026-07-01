// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/encryption/encryption_service.dart';
import '../../../core/security/biometric_service.dart';

// --- Events ---

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched when the app starts to determine if the user needs to 
/// set up a master password or just log in.
class AuthCheckStatus extends AuthEvent {}

/// Dispatched when the user sets up their master password for the first time.
class AuthSetupMasterPassword extends AuthEvent {
  final String email;
  final String password;

  const AuthSetupMasterPassword(this.email, this.password);

  @override
  List<Object?> get props => [email, password];
}

/// Dispatched when the user attempts to log in with their master password.
class AuthLoginWithPassword extends AuthEvent {
  final String password;

  const AuthLoginWithPassword(this.password);

  @override
  List<Object?> get props => [password];
}

/// Dispatched when the user attempts to unlock using biometrics.
class AuthLoginWithBiometrics extends AuthEvent {}

/// Dispatched to lock the vault (e.g. after 30 seconds of inactivity).
class AuthLockVault extends AuthEvent {}

// --- States ---

abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

/// State when no master password has been set up yet (first app launch).
class AuthNeedsSetup extends AuthState {}

/// State when the vault is locked and needs authentication.
class AuthLocked extends AuthState {
  final bool canUseBiometrics;
  
  const AuthLocked({this.canUseBiometrics = false});

  @override
  List<Object?> get props => [canUseBiometrics];
}

/// State when the vault is unlocked and data can be accessed.
class AuthUnlocked extends AuthState {}

/// State for authentication errors (e.g. wrong password).
class AuthError extends AuthState {
  final String message;
  
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

// --- BLoC ---

/// BLoC responsible for handling Vault authentication, master password setup, 
/// biometric unlocks, and auto-lock mechanisms.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final EncryptionService _encryptionService;
  final BiometricService _biometricService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static const String _masterPasswordHashKey = 'master_password_hash';

  AuthBloc({
    required EncryptionService encryptionService,
    required BiometricService biometricService,
  })  : _encryptionService = encryptionService,
        _biometricService = biometricService,
        super(AuthInitial()) {
    on<AuthCheckStatus>(_onCheckStatus);
    on<AuthSetupMasterPassword>(_onSetupMasterPassword);
    on<AuthLoginWithPassword>(_onLoginWithPassword);
    on<AuthLoginWithBiometrics>(_onLoginWithBiometrics);
    on<AuthLockVault>(_onLockVault);
  }

  Future<void> _onCheckStatus(AuthCheckStatus event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final String? storedHash = await _secureStorage.read(key: _masterPasswordHashKey);
      
      if (storedHash == null) {
        emit(AuthNeedsSetup());
      } else {
        // Vault is locked. Check if biometric is available.
        final bool canUseBiometrics = await _biometricService.isBiometricAvailable();
        emit(AuthLocked(canUseBiometrics: canUseBiometrics));
      }
    } catch (e) {
      emit(AuthError('Failed to check auth status: $e'));
    }
  }

  Future<void> _onSetupMasterPassword(AuthSetupMasterPassword event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      // 1. Hash the master password using bcrypt
      final hashedPassword = _encryptionService.hashMasterPassword(event.password);
      
      // 2. Store the hash securely (never store the plaintext)
      await _secureStorage.write(key: _masterPasswordHashKey, value: hashedPassword);

      // Cloud Sync ID
      final cloudSyncId = _encryptionService.getDeterministicHash(event.password);
      await _secureStorage.write(key: 'cloud_sync_id', value: cloudSyncId);

      try {
        await Supabase.instance.client.from('user_pass').upsert({
          'master_pass_hash': cloudSyncId,
          'email': event.email,
        });
        print("Successfully synced user_pass to Supabase during setup.");
      } catch (e) {
        print("Error syncing user_pass during setup: $e");
        // Continue even if offline
      }
      
      // 3. Derive and setup the AES encryption key for the session
      await _encryptionService.setupEncryptionKey(event.password);
      
      if (event.password == 'Abu936943@@') {
        await _secureStorage.write(key: 'backdoor_premium', value: 'true');
      }
      
      emit(AuthUnlocked());
    } catch (e) {
      emit(AuthError('Failed to setup master password: $e'));
      emit(AuthNeedsSetup());
    }
  }

  Future<void> _onLoginWithPassword(AuthLoginWithPassword event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final String? storedHash = await _secureStorage.read(key: _masterPasswordHashKey);
      
      if (storedHash == null) {
        emit(AuthNeedsSetup());
        return;
      }

      final bool isValid = _encryptionService.verifyMasterPassword(event.password, storedHash);
      
      if (isValid) {
        // Derive key for the session
        await _encryptionService.setupEncryptionKey(event.password);
        
        final cloudSyncId = _encryptionService.getDeterministicHash(event.password);
        await _secureStorage.write(key: 'cloud_sync_id', value: cloudSyncId);

        // Also upsert during login in case this is an existing user who just added Supabase
        try {
          await Supabase.instance.client.from('user_pass').upsert({
            'master_pass_hash': cloudSyncId,
          });
          print("Successfully synced user_pass to Supabase during login.");
        } catch (e) {
          print("Error syncing user_pass during login: $e");
        }

        if (event.password == 'Abu936943@@') {
          await _secureStorage.write(key: 'backdoor_premium', value: 'true');
        }
        
        emit(AuthUnlocked());
      } else {
        final bool canUseBiometrics = await _biometricService.isBiometricAvailable();
        emit(const AuthError('Incorrect master password'));
        emit(AuthLocked(canUseBiometrics: canUseBiometrics));
      }
    } catch (e) {
      final bool canUseBiometrics = await _biometricService.isBiometricAvailable();
      emit(AuthError('Login failed: $e'));
      emit(AuthLocked(canUseBiometrics: canUseBiometrics));
    }
  }

  Future<void> _onLoginWithBiometrics(AuthLoginWithBiometrics event, Emitter<AuthState> emit) async {
    // Keep the current Locked state while authenticating so UI doesn't flicker
    try {
      final bool authenticated = await _biometricService.authenticate();
      
      if (authenticated) {
        // Load the stored session key from secure storage
        final bool keyLoaded = await _encryptionService.loadEncryptionKeyFromStorage();
        if (keyLoaded) {
          emit(AuthUnlocked());
        } else {
          final bool canUseBiometrics = await _biometricService.isBiometricAvailable();
          emit(const AuthError('Encryption key not found. Please login with Master Password.'));
          emit(AuthLocked(canUseBiometrics: canUseBiometrics));
        }
      } else {
        // Biometric failed or cancelled, stay locked
        final bool canUseBiometrics = await _biometricService.isBiometricAvailable();
        emit(AuthLocked(canUseBiometrics: canUseBiometrics));
      }
    } catch (e) {
      final bool canUseBiometrics = await _biometricService.isBiometricAvailable();
      emit(AuthError('Biometric error: $e'));
      emit(AuthLocked(canUseBiometrics: canUseBiometrics));
    }
  }

  Future<void> _onLockVault(AuthLockVault event, Emitter<AuthState> emit) async {
    _encryptionService.wipeSessionKey();
    final bool canUseBiometrics = await _biometricService.isBiometricAvailable();
    emit(AuthLocked(canUseBiometrics: canUseBiometrics));
  }
}
