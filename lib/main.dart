import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/encryption/encryption_service.dart';
import 'core/security/biometric_service.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/premium/services/iap_service.dart';
import 'features/premium/bloc/premium_bloc.dart';
import 'features/vault/data/vault_repository.dart';
import 'features/vault/bloc/vault_bloc.dart';
import 'shared/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: 'https://nbjrutundzzyfbhlucyq.supabase.co', publishableKey: 'sb_publishable_4nZyBZfuRbzFtzzVSlkedg_CBn_6pig');

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize Core Services
  final encryptionService = EncryptionService();
  final biometricService = BiometricService();

  // Initialize Repositories and third-party services
  final vaultRepository = VaultRepository(encryptionService);
  await vaultRepository.init();

  final iapService = IAPService();
  await iapService.init();

  runApp(SecureVaultApp(encryptionService: encryptionService, biometricService: biometricService, vaultRepository: vaultRepository, iapService: iapService));
}

class SecureVaultApp extends StatefulWidget {
  final EncryptionService encryptionService;
  final BiometricService biometricService;
  final VaultRepository vaultRepository;
  final IAPService iapService;

  const SecureVaultApp({super.key, required this.encryptionService, required this.biometricService, required this.vaultRepository, required this.iapService});

  @override
  State<SecureVaultApp> createState() => _SecureVaultAppState();
}

class _SecureVaultAppState extends State<SecureVaultApp> {
  late final AuthBloc _authBloc;
  late final VaultBloc _vaultBloc;
  late final PremiumBloc _premiumBloc;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(encryptionService: widget.encryptionService, biometricService: widget.biometricService);
    _vaultBloc = VaultBloc(vaultRepository: widget.vaultRepository, iapService: widget.iapService);
    _premiumBloc = PremiumBloc(iapService: widget.iapService);
    // Check initial auth status (setup vs login)
    _authBloc.add(AuthCheckStatus());
    _appRouter = AppRouter(_authBloc);
  }

  @override
  void dispose() {
    _authBloc.close();
    _vaultBloc.close();
    _premiumBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<VaultRepository>.value(
      value: widget.vaultRepository,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _authBloc),
          BlocProvider<VaultBloc>.value(value: _vaultBloc),
          BlocProvider<PremiumBloc>.value(value: _premiumBloc),
        ],
        child: MaterialApp.router(
          title: 'SecureVault',
          themeMode: ThemeMode.dark, // Default to dark theme for security aesthetic
          theme: AppTheme.darkTheme, // We only have dark theme currently
          darkTheme: AppTheme.darkTheme,
          routerConfig: _appRouter.router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
