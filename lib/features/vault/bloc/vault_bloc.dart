// ignore_for_file: prefer_initializing_formals
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../data/vault_repository.dart';
import '../../premium/services/iap_service.dart';

// --- Events ---
abstract class VaultEvent extends Equatable {
  const VaultEvent();

  @override
  List<Object?> get props => [];
}

class VaultLoadPasswords extends VaultEvent {}

class VaultAddPassword extends VaultEvent {
  final PasswordEntry entry;
  const VaultAddPassword(this.entry);

  @override
  List<Object?> get props => [entry];
}

class VaultUpdatePassword extends VaultEvent {
  final PasswordEntry entry;
  const VaultUpdatePassword(this.entry);

  @override
  List<Object?> get props => [entry];
}

class VaultDeletePassword extends VaultEvent {
  final String id;
  const VaultDeletePassword(this.id);

  @override
  List<Object?> get props => [id];
}

class VaultRestoreFromCloud extends VaultEvent {}

// --- States ---
abstract class VaultState extends Equatable {
  const VaultState();
  
  @override
  List<Object?> get props => [];
}

class VaultInitial extends VaultState {}

class VaultLoading extends VaultState {}

class VaultLoaded extends VaultState {
  final List<PasswordEntry> passwords;

  const VaultLoaded(this.passwords);

  @override
  List<Object?> get props => [passwords];
}

class VaultRequiresUpgrade extends VaultState {}

class VaultError extends VaultState {
  final String message;

  const VaultError(this.message);

  @override
  List<Object?> get props => [message];
}

// --- BLoC ---
class VaultBloc extends Bloc<VaultEvent, VaultState> {
  final VaultRepository _vaultRepository;
  final IAPService _iapService;

  static const int _freeTierLimit = 10;

  VaultBloc({
    required VaultRepository vaultRepository,
    required IAPService iapService,
  })  : _vaultRepository = vaultRepository,
        _iapService = iapService,
        super(VaultInitial()) {
    on<VaultLoadPasswords>(_onLoadPasswords);
    on<VaultAddPassword>(_onAddPassword);
    on<VaultUpdatePassword>(_onUpdatePassword);
    on<VaultDeletePassword>(_onDeletePassword);
    on<VaultRestoreFromCloud>(_onRestoreFromCloud);
  }

  Future<void> _onLoadPasswords(VaultLoadPasswords event, Emitter<VaultState> emit) async {
    emit(VaultLoading());
    try {
      final passwords = await _vaultRepository.getAllPasswords();
      emit(VaultLoaded(passwords));
    } catch (e) {
      emit(VaultError('Failed to load passwords: $e'));
    }
  }

  Future<void> _onAddPassword(VaultAddPassword event, Emitter<VaultState> emit) async {
    final currentState = state;
    if (currentState is! VaultLoaded) return;

    try {
      final currentTier = await _iapService.getCurrentTier();
      if (currentTier == SubscriptionTier.free && currentState.passwords.length >= _freeTierLimit) {
        emit(VaultRequiresUpgrade());
        // Re-emit loaded so the UI can still show the list behind the paywall prompt
        emit(VaultLoaded(currentState.passwords));
        return;
      }

      await _vaultRepository.addPassword(event.entry);
      // Reload passwords to ensure fresh state
      add(VaultLoadPasswords());
    } catch (e) {
      emit(VaultError('Failed to add password: $e'));
      emit(VaultLoaded(currentState.passwords));
    }
  }

  Future<void> _onUpdatePassword(VaultUpdatePassword event, Emitter<VaultState> emit) async {
    final currentState = state;
    if (currentState is! VaultLoaded) return;

    try {
      await _vaultRepository.updatePassword(event.entry);
      add(VaultLoadPasswords());
    } catch (e) {
      emit(VaultError('Failed to update password: $e'));
      emit(VaultLoaded(currentState.passwords));
    }
  }

  Future<void> _onDeletePassword(VaultDeletePassword event, Emitter<VaultState> emit) async {
    final currentState = state;
    if (currentState is! VaultLoaded) return;

    try {
      await _vaultRepository.deletePassword(event.id);
      add(VaultLoadPasswords());
    } catch (e) {
      emit(VaultError('Failed to delete password: $e'));
      emit(VaultLoaded(currentState.passwords));
    }
  }

  Future<void> _onRestoreFromCloud(VaultRestoreFromCloud event, Emitter<VaultState> emit) async {
    final currentState = state;
    if (currentState is! VaultLoaded) return;

    emit(VaultLoading());
    try {
      final currentTier = await _iapService.getCurrentTier();
      if (currentTier == SubscriptionTier.free) {
        emit(VaultRequiresUpgrade());
        emit(VaultLoaded(currentState.passwords));
        return;
      }

      await _vaultRepository.restoreFromCloud();
      add(VaultLoadPasswords());
    } catch (e) {
      emit(VaultError('Failed to restore from cloud: $e'));
      emit(VaultLoaded(currentState.passwords));
    }
  }
}
