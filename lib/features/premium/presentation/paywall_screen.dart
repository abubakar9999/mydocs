import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
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

  Widget _buildBenefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.teal),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade to Premium'),
        actions: [
          TextButton(
            onPressed: () {
              context.read<PremiumBloc>().add(PremiumRestorePurchases());
            },
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: BlocConsumer<PremiumBloc, PremiumState>(
        listener: (context, state) {
          if (state is PremiumError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          } else if (state is PremiumLoaded) {
            if (state.currentTier != SubscriptionTier.free) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Welcome to Premium!')),
              );
              context.pop(); // Close paywall on success
            }
          }
        },
        builder: (context, state) {
          if (state is PremiumLoading || state is PremiumInitial) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }

          if (state is PremiumLoaded) {
            final packages = state.availablePackages;
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
                  const SizedBox(height: 16),
                  const Text(
                    'Unlock SecureVault Premium',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  
                  // Benefits
                  _buildBenefitRow('Unlimited Passwords'),
                  _buildBenefitRow('Family Sharing (Up to 5 members)'),
                  _buildBenefitRow('Priority Support'),
                  _buildBenefitRow('Advanced Security Analytics'),
                  
                  const SizedBox(height: 48),

                  if (packages.isEmpty)
                    const Text(
                      'No subscription plans available at the moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
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

  Widget _buildPackageCard(Package pkg) {
    final isAnnual = pkg.packageType == PackageType.annual;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () {
          context.read<PremiumBloc>().add(PremiumPurchasePackage(pkg));
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            border: Border.all(color: isAnnual ? Colors.amber : Colors.teal, width: isAnnual ? 2 : 1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pkg.storeProduct.title.split(' (').first, 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (isAnnual)
                    const Text('Best Value', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              Text(
                pkg.storeProduct.priceString,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
