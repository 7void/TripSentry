import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/blockchain_provider.dart';

class WalletSetupScreen extends StatefulWidget {
  const WalletSetupScreen({super.key});

  @override
  State<WalletSetupScreen> createState() => _WalletSetupScreenState();
}

class _WalletSetupScreenState extends State<WalletSetupScreen> {
  bool _showPrivateKey = false;

  @override
  void initState() {
    super.initState();
    // Initialize blockchain services when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBlockchainServices();
    });
  }

  Future<void> _initializeBlockchainServices() async {
    final blockchainProvider = Provider.of<BlockchainProvider>(context, listen: false);
    
    try {
      await blockchainProvider.initializeBlockchainServices();
    } catch (e) {
      if (!mounted) return;
      
      // Show initialization error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initialize blockchain services: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _initializeBlockchainServices,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Consumer<BlockchainProvider>(
            builder: (context, blockchainProvider, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.account_balance_wallet,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to Tourist Safety',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'To get started, we need to create a secure blockchain wallet for your digital Tourist ID.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  if (blockchainProvider.wallet == null) ...[
                    _buildFeatureList(context),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: blockchainProvider.isLoading
                            ? null
                            : () => _createWallet(context, blockchainProvider),
                        child: blockchainProvider.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Create Wallet'),
                      ),
                    ),
                  ] else ...[
                    _buildWalletInfo(context, blockchainProvider),
                  ],
                  
                  if (blockchainProvider.hasError) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error, color: Colors.red.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Error',
                                  style: TextStyle(
                                    color: Colors.red.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  blockchainProvider.errorMessage,
                                  style: TextStyle(color: Colors.red.shade600),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              blockchainProvider.clearError();
                              _initializeBlockchainServices();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const Spacer(),
                  
                  Text(
                    'Your wallet is secured by blockchain technology',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureList(BuildContext context) {
    return Column(
      children: [
        _buildFeatureItem(
          context,
          Icons.security,
          'Secure & Private',
          'Your keys are stored securely on your device only',
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          context,
          Icons.verified_user,
          'Blockchain Verified',
          'Digital ID backed by immutable blockchain technology',
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          context,
          Icons.lock_outline,
          'Soulbound Token',
          'Your Tourist ID cannot be transferred or stolen',
        ),
      ],
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWalletInfo(BuildContext context, BlockchainProvider blockchainProvider) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            border: Border.all(color: Colors.green.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                Icons.check_circle,
                size: 48,
                color: Colors.green.shade600,
              ),
              const SizedBox(height: 12),
              Text(
                'Wallet Created Successfully!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(context, 'Address:', blockchainProvider.shortWalletAddress ?? 'N/A'),
              const SizedBox(height: 8),
              if (blockchainProvider.wallet?.privateKey != null)
                _buildCopyableRow(
                  context,
                  'Private Key:',
                  _showPrivateKey
                      ? blockchainProvider.wallet!.privateKey
                      : '•' * 32,
                  blockchainProvider.wallet!.privateKey,
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showPrivateKey = !_showPrivateKey;
                  });
                },
                icon: Icon(_showPrivateKey ? Icons.visibility_off : Icons.visibility),
                label: Text(_showPrivateKey ? 'Hide Private Key' : 'Show Private Key'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border.all(color: Colors.orange.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Save your private key securely! It\'s the only way to recover your wallet.',
                  style: TextStyle(color: Colors.orange.shade600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/home');
            },
            child: const Text('Continue to App'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCopyableRow(BuildContext context, String label, String displayValue, String copyValue) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            displayValue,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: copyValue));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.copy, size: 16),
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Future<void> _createWallet(BuildContext context, BlockchainProvider blockchainProvider) async {
    try {
      await blockchainProvider.createWallet();
      
      if (blockchainProvider.hasError) {
        if (!context.mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create wallet: ${blockchainProvider.errorMessage}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _createWallet(context, blockchainProvider),
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}