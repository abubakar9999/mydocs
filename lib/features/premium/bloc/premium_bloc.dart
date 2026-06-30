// ignore_for_file: prefer_initializing_formals
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/iap_service.dart';

// --- Events ---
abstract class PremiumEvent extends Equatable {
  const PremiumEvent();
  @override
  List<Object?> get props => [];
}

class PremiumLoadOfferings extends PremiumEvent {}

class PremiumPurchasePackage extends PremiumEvent {
  final Package package;
  const PremiumPurchasePackage(this.package);
  @override
  List<Object?> get props => [package];
}

class PremiumRestorePurchases extends PremiumEvent {}

// --- States ---
abstract class PremiumState extends Equatable {
  const PremiumState();
  @override
  List<Object?> get props => [];
}

class PremiumInitial extends PremiumState {}

class PremiumLoading extends PremiumState {}

class PremiumLoaded extends PremiumState {
  final SubscriptionTier currentTier;
  final List<Package> availablePackages;

  const PremiumLoaded({
    required this.currentTier,
    required this.availablePackages,
  });

  @override
  List<Object?> get props => [currentTier, availablePackages];
}

class PremiumError extends PremiumState {
  final String message;
  const PremiumError(this.message);
  @override
  List<Object?> get props => [message];
}

// --- BLoC ---
class PremiumBloc extends Bloc<PremiumEvent, PremiumState> {
  final IAPService _iapService;

  PremiumBloc({required IAPService iapService})
      : _iapService = iapService,
        super(PremiumInitial()) {
    on<PremiumLoadOfferings>(_onLoadOfferings);
    on<PremiumPurchasePackage>(_onPurchasePackage);
    on<PremiumRestorePurchases>(_onRestorePurchases);
  }

  Future<void> _onLoadOfferings(PremiumLoadOfferings event, Emitter<PremiumState> emit) async {
    emit(PremiumLoading());
    try {
      final tier = await _iapService.getCurrentTier();
      final offerings = await _iapService.getOfferings();
      
      List<Package> packages = [];
      if (offerings != null && offerings.current != null) {
        packages = offerings.current!.availablePackages;
      }
      
      emit(PremiumLoaded(currentTier: tier, availablePackages: packages));
    } catch (e) {
      emit(PremiumError('Failed to load premium details: $e'));
    }
  }

  Future<void> _onPurchasePackage(PremiumPurchasePackage event, Emitter<PremiumState> emit) async {
    emit(PremiumLoading());
    try {
      final success = await _iapService.purchasePackage(event.package);
      if (success) {
        add(PremiumLoadOfferings());
      } else {
        emit(const PremiumError('Purchase failed or was cancelled.'));
      }
    } catch (e) {
      emit(PremiumError('An error occurred during purchase: $e'));
    }
  }

  Future<void> _onRestorePurchases(PremiumRestorePurchases event, Emitter<PremiumState> emit) async {
    emit(PremiumLoading());
    try {
      final success = await _iapService.restorePurchases();
      if (success) {
        add(PremiumLoadOfferings());
      } else {
        emit(const PremiumError('No active subscriptions found to restore.'));
      }
    } catch (e) {
      emit(PremiumError('Failed to restore purchases: $e'));
    }
  }
}
