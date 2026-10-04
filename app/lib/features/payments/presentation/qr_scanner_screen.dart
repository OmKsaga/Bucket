import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import 'payment_sheet.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  void _handleQrData(String qrString) {
    String recipient = qrString;
    int? prefilledAmountRupees;

    // Parse UPI URI format: upi://pay?pa=...&pn=...&am=...
    if (qrString.startsWith('upi://pay')) {
      final uri = Uri.tryParse(qrString);
      if (uri != null) {
        final pa = uri.queryParameters['pa'];
        final pn = uri.queryParameters['pn'];
        final am = uri.queryParameters['am'];
        recipient = pn != null && pn.isNotEmpty ? '$pn ($pa)' : (pa ?? qrString);
        if (am != null) {
          prefilledAmountRupees = double.tryParse(am)?.toInt();
        }
      }
    }

    _openPaymentSheet(recipient, prefilledAmountRupees);
  }

  void _openPaymentSheet(String recipient, int? initialAmount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => PaymentSheet(
        title: 'Scan & Pay',
        defaultRecipient: recipient,
      ),
    );
  }

  void _showManualEntryDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Enter UPI ID / VPA'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. merchant@icici or 9876543210@upi',
            prefixIcon: Icon(Icons.alternate_email),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(ctx).pop();
                _handleQrData(text);
              }
            },
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan any UPI QR'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              setState(() => _isFlashOn = !_isFlashOn);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Viewfinder Background
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.primaryAccent, width: 3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: Stack(
                  children: [
                    Container(
                      color: Colors.white.withOpacity(0.05),
                    ),
                    // Animated Laser Scanning Line
                    AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: _laserAnimation.value * 260,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryAccent.withOpacity(0.1),
                                  AppTheme.primaryAccent,
                                  AppTheme.primaryAccent.withOpacity(0.1),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryAccent.withOpacity(0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Instructions at Top
          const Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Text(
                  'Align QR code within the frame',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Supports Google Pay, PhonePe, Paytm, BharatPe, BHIM',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ),

          // Bottom Controls & Simulation Presets
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // Quick Test Barcode Simulators
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Simulate QR Scan (Tap to Test)',
                        style: TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                side: const BorderSide(color: AppTheme.primaryAccent),
                              ),
                              onPressed: () => _handleQrData(
                                'upi://pay?pa=bluetokai@icici&pn=Blue+Tokai+Coffee&am=280.00&cu=INR&tn=Cold+Brew',
                              ),
                              child: const Text('☕ Coffee ₹280', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                side: const BorderSide(color: AppTheme.warningAmber),
                              ),
                              onPressed: () => _handleQrData(
                                'upi://pay?pa=swiggy@axisbank&pn=Swiggy+Order&am=650.00&cu=INR&tn=Dinner',
                              ),
                              child: const Text('🍔 Swiggy ₹650', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                side: const BorderSide(color: AppTheme.dangerRose),
                              ),
                              onPressed: () => _handleQrData(
                                'upi://pay?pa=electronics@hdfcbank&pn=Gadget+Store&am=12000.00&cu=INR&tn=Headphones',
                              ),
                              child: const Text('🎧 ₹12,000', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Manual VPA or Gallery Fallback Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.image_outlined, color: Colors.white70),
                      label: const Text('Upload from Gallery', style: TextStyle(color: Colors.white70)),
                      onPressed: () {
                        // Demo gallery trigger
                        _handleQrData('upi://pay?pa=merchant.gallery@okaxis&pn=Gallery+Store&am=350.00');
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.keyboard_alt_outlined, color: AppTheme.primaryAccent),
                      label: const Text('Enter UPI ID', style: TextStyle(color: AppTheme.primaryAccent)),
                      onPressed: _showManualEntryDialog,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
