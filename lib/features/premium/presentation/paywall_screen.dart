import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../shared/theme/app_theme.dart';
import '../bloc/premium_bloc.dart';
import '../services/iap_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PremiumBloc>().add(PremiumLoadOfferings());
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Premium'),
        actions: [
          TextButton(
            onPressed: () => context.read<PremiumBloc>().add(PremiumRestorePurchases()),
            child: const Text('Restore', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
      body: BlocConsumer<PremiumBloc, PremiumState>(
        listener: (context, state) {
          if (state is PremiumError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
            );
          } else if (state is PremiumLoaded) {
            if (state.currentTier != SubscriptionTier.free) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Welcome to Premium!')),
              );
              context.pop();
            }
          }
        },
        builder: (context, state) {
          if (state is PremiumLoading || state is PremiumInitial) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan));
          }

          if (state is PremiumLoaded) {
            final packages = state.availablePackages;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Hero premium icon
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.goldGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentAmber.withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, size: 48, color: AppColors.bgDark),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Unlock Premium',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Get the most out of SecureVault',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                  ),
                  const SizedBox(height: 32),

                  // Benefits
                  GlassContainer(
                    child: Column(
                      children: [
                        _buildBenefitRow(Icons.all_inclusive_rounded, 'Unlimited Passwords', AppColors.primaryCyan),
                        const SizedBox(height: 16),
                        _buildBenefitRow(Icons.image_rounded, 'Unlimited Documents', AppColors.success),
                        const SizedBox(height: 16),
                        _buildBenefitRow(Icons.cloud_sync_rounded, 'Cloud Sync & Backup', AppColors.accentAmber),
                        const SizedBox(height: 16),
                        _buildBenefitRow(Icons.family_restroom_rounded, 'Family Sharing (5 members)', Color(0xFF7C4DFF)),
                        const SizedBox(height: 16),
                        _buildBenefitRow(Icons.support_agent_rounded, 'Priority Support', Color(0xFF448AFF)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Plans
                  if (packages.isEmpty)
                    const Text(
                      'No plans available at the moment.',
                      style: TextStyle(color: AppColors.textMuted),
                    )
                  else
                    ...packages.map((pkg) => _buildPackageCard(pkg)),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
        ),
        Icon(Icons.check_rounded, color: color, size: 20),
      ],
    );
  }

  Widget _buildPackageCard(Package pkg) {
    final isAnnual = pkg.packageType == PackageType.annual;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => context.read<PremiumBloc>().add(PremiumPurchasePackage(pkg)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isAnnual ? AppColors.accentAmber : AppColors.glassBorder,
              width: isAnnual ? 2 : 1,
            ),
            boxShadow: isAnnual
                ? [BoxShadow(color: AppColors.accentAmber.withValues(alpha: 0.15), blurRadius: 20)]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          pkg.storeProduct.title.split(' (').first,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        if (isAnnual) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Best Value', style: TextStyle(color: AppColors.bgDark, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                pkg.storeProduct.priceString,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primaryCyan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
