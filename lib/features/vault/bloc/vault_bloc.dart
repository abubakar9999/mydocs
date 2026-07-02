// ignore_for_file: prefer_initializing_formals
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../data/vault_repository.dart';
import '../data/document_entry.dart';
import '../../premium/services/iap_service.dart';

// --- Events ---
abstract class VaultEvent extends Equatable {
  const VaultEvent();

  @override
  List<Object?> get props => [];
}

class VaultLoadData extends VaultEvent {}

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

class VaultAddDocument extends VaultEvent {
  final DocumentEntry entry;
  final Uint8List imageBytes;
  const VaultAddDocument(this.entry, this.imageBytes);

  @override
  List<Object?> get props => [entry, imageBytes];
}

class VaultDeleteDocument extends VaultEvent {
  final DocumentEntry entry;
  const VaultDeleteDocument(this.entry);

  @override
  List<Object?> get props => [entry];
}

class VaultSyncDocumentsToCloud extends VaultEvent {}

class VaultRestoreDocumentsFromCloud extends VaultEvent {}


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
  final List<DocumentEntry> documents;

  const VaultLoaded({required this.passwords, required this.documents});

  @override
  List<Object?> get props => [passwords, documents];
}

class VaultRequiresUpgrade extends VaultState {
  final String message;
  const VaultRequiresUpgrade({this.message = 'You have reached the free limit. Upgrade to Premium.'});
  @override
  List<Object?> get props => [message];
}

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

  static const int _freeTierPasswordLimit = 10;
  static const int _freeTierDocumentLimit = 3;

  VaultBloc({
    required VaultRepository vaultRepository,
    required IAPService iapService,
  })  : _vaultRepository = vaultRepository,
        _iapService = iapService,
        super(VaultInitial()) {
    on<VaultLoadData>(_onLoadData);
    on<VaultAddPassword>(_onAddPassword);
    on<VaultUpdatePassword>(_onUpdatePassword);
    on<VaultDeletePassword>(_onDeletePassword);
    on<VaultRestoreFromCloud>(_onRestoreFromCloud);
    on<VaultAddDocument>(_onAddDocument);
    on<VaultDeleteDocument>(_onDeleteDocument);
    on<VaultSyncDocumentsToCloud>(_onSyncDocumentsToCloud);
    on<VaultRestoreDocumentsFromCloud>(_onRestoreDocumentsFromCloud);
  }

  Future<void> _onLoadData(VaultLoadData event, Emitter<VaultState> emit) async {
    emit(VaultLoading());
    try {
      final passwords = await _vaultRepository.getAllPasswords();
      final documents = await _vaultRepository.getAllDocuments();
      emit(VaultLoaded(passwords: passwords, documents: documents));
    } catch (e) {
      emit(VaultError('Failed to load data: $e'));
    }
  }

  Future<void> _onAddPassword(VaultAddPassword event, Emitter<VaultState> emit) async {
    final currentState = state;
    if (currentState is! VaultLoaded) return;

    try {
      final currentTier = await _iapService.getCurrentTier();
      if (currentTier == SubscriptionTier.free && currentState.passwords.length >= _freeTierPasswordLimit) {
        emit(const VaultRequiresUpgrade(message: 'You have reached the free limit of 10 passwords.'));
        emit(VaultLoaded(passwords: currentState.passwords, documents: currentState.documents));
        return;
      }

      await _vaultRepository.addPassword(event.entry);
      add(VaultLoadData());
    } catch (e) {
      emit(VaultError('Failed to add password: $e'));
      emit(VaultLoaded(passwords: currentState.passwords, documents: currentState.documents));
    }
  }

  Future<void> _onUpdatePassword(VaultUpdatePassword event, Emitter<VaultState> emit) async {
    final currentState = state;
    if (currentState is! VaultLoaded) return;

    try {
      await _vaultRepository.updatePassword(event.entry);
      add(VaultLoadData());
    } catch (e) {
      emit(VaultError('Failed to update password: $e'));
      emit(VaultLoaded(passwords: currentState.passwords, documents: currentState.documents));
    }
  }

  Future<void> _onDeletePassword(VaultDeletePassword event, Emitter<VaultState> emit) async {
    final currentState = state;
    if (currentState is! VaultLoaded) return;

    try {
      await _vaultRepository.deletePassword(event.id);
      add(VaultLoadData());
    } catch (e) {
      emit(VaultError('Failed to delete password: $e'));
      emit(VaultLoaded(passwords: currentState.passwords, documents: currentState.documents));
    }
  }

  Future<void> _onRestoreFromCloud(VaultRestoreFromCloud event, Emitter<VaultState> emit) async {
    final currentState = state;
    if (currentState is! VaultLoaded) return;

    emit(VaultLoading());
    try {
      final currentTier = await _iapService.getCurrentTier();
      if (currentTier == SubscriptionTier.free) {
        emit(const VaultRequiresUpgrade(message: 'Cloud restore is a premium feature.'));
        emit(VaultLoaded(passwords: currentState.passwords, documents: currentState.documents));
        return;
      }

      await _vaultRepository.restoreFromCloud();
      add(VaultLoadData());
    } catch (e) {
      emit(VaultError('Failed to restore from cloud: $e'));
      emit(VaultLoaded(passwords: currentState.passwords, documents: currentState.documents));
    }
  }

  Future<void> _onAddDocument(VaultAddDocument event, Emitter<VaultState> emit) async {
    final currentState = state;
    if (currentState is! VaultLoaded) return;

    try {
      final currentTier = await _iapService.getCurrentTier();
      if (currentTier == SubscriptionTier.free && currentState.documents.length >= _freeTierDocumentLimit) {
        emit(const VaultRequiresUpgrade(message: 'You have reached the free limit of 3 documents.'));
        emit(VaultLoaded(passwords: currentState.passwords, documents: currentState.documents));
        return;
      }

      await _vaultRepository.addDocument(event.entry, event.imageBytes);
      add(VaultLoadData());
    } catch (e) {
      emit(VaultError('Failed to add document: $e'));
      emit(VaultLoaded(passwords: currentState.passwords, documents: currentState.documents));
    }
  }

  Future<void> _onDeleteDocument(VaultDeleteDocument event, Emitter<VaultState> emit) async {
    final currentState = state;
    if (currentState is! VaultLoaded) return;

    try {
      await _vaultRepository.deleteDocument(event.entry);
      add(VaultLoadData());
    } catch (e) {
      emit(VaultError('Failed to delete document: $e'));
      emit(VaultLoaded(passwords: currentState.passwords, documents: currentState.documents));
    }
  }

  Future<void> _onSyncDocumentsToCloud(VaultSyncDocumentsToCloud event, Emitter<VaultState> emit) async {
    final currentState = state;
    if (currentState is! VaultLoaded) return;

    emit(VaultLoading());
    try {
      final currentTier = await _iapService.getCurrentTier();
      if (currentTier == SubscriptionTier.free) {
        emit(const VaultRequiresUpgrade(message: 'Cloud sync for documents is a premium feature.'));
        emit(VaultLoaded(passwords: currentState.passwords, documents: currentState.documents));
        return;
      }

      await _vaultRepository.syncDocumentsToCloud();
      emit(VaultLoaded(passwords: currentState.passwords, documents: currentState.documents));
    } catch (e) {
      emit(VaultError('Failed to sync documents to cloud: $e'));
      emit(VaultLoaded(passwords: currentState.passwords, documents: currentState.documents));
    }
  }

  Future<void> _onRestoreDocumentsFromCloud(VaultRestoreDocumentsFromCloud event, Emitter<VaultState> emit) async {
    final currentState = state;
    if (currentState is! VaultLoaded) return;

    emit(VaultLoading());
    try {
      final currentTier = await _iapService.getCurrentTier();
      if (currentTier == SubscriptionTier.free) {
        emit(const VaultRequiresUpgrade(message: 'Cloud restore for documents is a premium feature.'));
        emit(VaultLoaded(passwords: currentState.passwords, documents: currentState.documents));
        return;
      }

      await _vaultRepository.restoreDocumentsFromCloud();
      add(VaultLoadData());
    } catch (e) {
      emit(VaultError('Failed to restore documents from cloud: $e'));
      emit(VaultLoaded(passwords: currentState.passwords, documents: currentState.documents));
    }
  }
}
