import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/blockchain_provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/location_service_helper.dart';
import '../services/health_sync_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appNameShort)),
      body: Consumer<BlockchainProvider>(
        builder: (context, bp, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildIdSection(context, bp),
              const SizedBox(height: 16),
              _buildLanguageSection(context),
              const SizedBox(height: 24),
              _buildLogoutButton(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIdSection(BuildContext context, BlockchainProvider bp) {
    final l10n = AppLocalizations.of(context);
    if (bp.hasActiveTouristID && bp.touristRecord != null) {
      final record = bp.touristRecord!;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(l10n.touristId,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context)
                        .pushNamed('/tourist-id-details'),
                    icon: const Icon(Icons.visibility),
                    label: Text(l10n.viewId),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _kv(context, l10n.tokenId, '#${bp.tokenId}'),
              const SizedBox(height: 8),
              _kv(context, l10n.validUntil,
                  '${record.validUntil.day}/${record.validUntil.month}/${record.validUntil.year}'),
            ],
          ),
        ),
      );
    }
    // No ID
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_outlined, color: Colors.grey),
                const SizedBox(width: 8),
                Text(l10n.touristId,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.noTouristIdBody,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/tourist-id-registration'),
                icon: const Icon(Icons.add),
                label: Text(l10n.createTouristId),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = Localizations.localeOf(context);
    String code = current.languageCode;
    if (!['en', 'hi', 'bn', 'ta', 'te', 'ml'].contains(code)) code = 'en';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(l10n.language,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: code,
                items: [
                  DropdownMenuItem(value: 'en', child: const Text('English')),
                  DropdownMenuItem(value: 'hi', child: const Text('हिंदी')),
                  DropdownMenuItem(value: 'bn', child: const Text('বাংলা')),
                  DropdownMenuItem(value: 'ta', child: const Text('தமிழ்')),
                  DropdownMenuItem(value: 'te', child: const Text('తెలుగు')),
                  DropdownMenuItem(value: 'ml', child: const Text('മലയാളം')),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  Locale? newLocale;
                  switch (val) {
                    case 'en':
                      newLocale = const Locale('en');
                      break;
                    case 'hi':
                      newLocale = const Locale('hi');
                      break;
                    case 'bn':
                      newLocale = const Locale('bn');
                      break;
                    case 'ta':
                      newLocale = const Locale('ta');
                      break;
                    case 'te':
                      newLocale = const Locale('te');
                      break;
                    case 'ml':
                      newLocale = const Locale('ml');
                      break;
                  }
                  if (newLocale != null) {
                    context.read<LocaleProvider>().setLocale(newLocale);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ElevatedButton.icon(
      onPressed: () async {
        try {
          await FirebaseAuth.instance.signOut();
          await LocationServiceHelper.stopService();
          try {
            HealthSyncService.instance.stop();
          } catch (_) {}
        } finally {
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        }
      },
      icon: const Icon(Icons.logout),
      label: Text(l10n.menuLogout),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(k,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(v)),
      ],
    );
  }
}
