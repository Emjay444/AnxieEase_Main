import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../search.dart';

/// Show the critical-alert help modal. Shared by every entry point that can
/// surface a critical anxiety alert (push notification tap, local
/// notification background action, cold start, and the in-app Notifications
/// list) so the experience is identical regardless of how the user got here.
///
/// This also marks the notification as a confirmed critical anxiety episode
/// in the database, matching the pre-existing behavior: critical alerts are
/// a definitive backend severity calculation, not something the user is
/// asked to confirm via the Yes/No dialog.
Future<void> showCriticalAlertHelpModal({
  required BuildContext context,
  String? notificationTitle,
  String? notificationMessage,
  String? notificationId,
}) async {
  try {
    // Get user's emergency contact
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final emergencyContact = user?.emergencyContact;

    await showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return CriticalAlertHelpModalWidget(
          emergencyContact: emergencyContact,
          notificationId: notificationId,
        );
      },
    );

    // CRITICAL: Mark this critical alert as confirmed anxiety attack in the database
    if (notificationId != null) {
      try {
        final supabaseService = SupabaseService();
        // Mark the notification as answered with confirmed = true (anxiety attack)
        await supabaseService.markNotificationAsAnswered(
          notificationId,
          response:
              'CONFIRMED_CRITICAL', // Confirmed as critical anxiety attack
          severity: 'critical', // severity level
        );
        debugPrint(
            '✅ Critical alert automatically marked as confirmed anxiety attack in database');
      } catch (e) {
        debugPrint('❌ Error marking critical alert as confirmed: $e');
      }
    } else {
      debugPrint(
          '⚠️ No notification ID provided for critical alert confirmation');
    }
  } catch (e) {
    debugPrint('❌ Error showing critical alert help modal: $e');
  }
}

class CriticalAlertHelpModalWidget extends StatefulWidget {
  final String? emergencyContact;
  final String? notificationId;

  const CriticalAlertHelpModalWidget({
    super.key,
    this.emergencyContact,
    this.notificationId,
  });

  @override
  State<CriticalAlertHelpModalWidget> createState() =>
      _CriticalAlertHelpModalWidgetState();
}

class _CriticalAlertHelpModalWidgetState
    extends State<CriticalAlertHelpModalWidget> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Unfocus any text fields and trigger a rebuild when returning from external apps
      FocusScope.of(context).unfocus();
      if (mounted) {
        setState(() {
          // Trigger a rebuild to refresh the UI state
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red.withOpacity(0.05),
                Colors.white,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite,
                      color: Colors.red[700],
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'re Not Alone - We\'re Here to Help',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.psychology,
                                  color: Colors.blue[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'First, take a moment to breathe slowly and deeply',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• You are not alone in this\n• This feeling can pass\n• Focus on your breathing: in for 4, hold for 4, out for 6\n• Use the resources below when you\'re ready',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[600],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable content section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Immediate Self-Care Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.green.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.self_improvement,
                                    color: Colors.green[700], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Immediate Relief Techniques',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Try these calming techniques first:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.green[600],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.green.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🫁 4-7-8 Breathing: Breathe in for 4 counts, hold for 7, exhale for 8',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '🌿 5-4-3-2-1 Grounding: Name 5 things you see, 4 you feel, 3 you hear, 2 you smell, 1 you taste',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '💭 Try reminding yourself: "This feeling can pass. I can take this one moment at a time."',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Emergency Contact Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.red.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.phone_in_talk,
                                    color: Colors.red[700], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Emergency Contacts',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // User's Personal Emergency Contact (if available)
                            if (widget.emergencyContact != null &&
                                widget.emergencyContact!.trim().isNotEmpty) ...[
                              _buildContactChip(
                                label: 'Your Emergency Contact',
                                number: widget.emergencyContact!.trim(),
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 8),
                            ],

                            // NCMH Crisis Hotlines
                            Text(
                              'NCMH (National Center for Mental Health) Crisis Hotline',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.red[700],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildContactChip(
                              label: 'Main Hotline',
                              number: '1553',
                              color: Colors.red,
                            ),
                            const SizedBox(height: 6),
                            _buildContactChip(
                              label: 'Alternative',
                              number: '180018881553',
                              color: Colors.red,
                            ),
                            const SizedBox(height: 6),
                            _buildContactChip(
                              label: 'Smart/TNT',
                              number: '09190571553',
                              color: Colors.red,
                            ),
                            const SizedBox(height: 6),
                            _buildContactChip(
                              label: 'Globe/TM',
                              number: '09178998727',
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),

                      // Action Buttons
                      Column(
                        children: [
                          // Reassuring message before emergency options
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.orange[700], size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'If breathing techniques don\'t help and you feel unsafe, reach out for support:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Emergency Call 911 Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _makeEmergencyCall('911'),
                              icon: const Icon(Icons.emergency,
                                  color: Colors.white, size: 20),
                              label: const Text(
                                  'Emergency Call 911 (if in danger)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Breathing Exercise Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final navigator =
                                    Navigator.of(context, rootNavigator: true);
                                Navigator.pop(context);
                                navigator.pushNamed('/breathing');
                              },
                              icon: const Icon(Icons.air, color: Colors.white),
                              label: const Text('Guided Breathing Exercise'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Grounding Technique Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final navigator =
                                    Navigator.of(context, rootNavigator: true);
                                Navigator.pop(context);
                                navigator.pushNamed('/grounding');
                              },
                              icon: const Icon(Icons.self_improvement,
                                  color: Colors.white),
                              label: const Text('5-4-3-2-1 Grounding Exercise'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Find Nearest Clinic Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final navigator =
                                    Navigator.of(context, rootNavigator: true);
                                Navigator.pop(context);
                                navigator.push(
                                  MaterialPageRoute(
                                    builder: (context) => const SearchScreen(),
                                  ),
                                );
                              },
                              icon: Icon(Icons.local_hospital,
                                  color: Colors.red[700]),
                              label: const Text('Find Nearest Clinic'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red[700],
                                side: BorderSide(color: Colors.red[700]!),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Encouraging message
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.favorite,
                                    color: Colors.purple[600], size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You\'re taking a brave step by being here. One moment at a time.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple[600],
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Icon(Icons.favorite,
                                    color: Colors.purple[600], size: 16),
                              ],
                            ),
                          ),

                          // Close Button
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'I\'m feeling better now',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactChip({
    required String label,
    required String number,
    required MaterialColor color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _makePhoneCall(number),
        icon: const Icon(Icons.phone, color: Colors.white, size: 16),
        label: Text('$label: $number'),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final dialerUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(dialerUri)) {
        await launchUrl(dialerUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch dialer for $phoneNumber'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching phone dialer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please manually dial $phoneNumber'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _makeEmergencyCall(String emergencyNumber) async {
    try {
      // Method 1: Try direct Android intent for dialer
      final dialerUri = Uri(scheme: 'tel', path: emergencyNumber);
      if (await canLaunchUrl(dialerUri)) {
        await launchUrl(dialerUri, mode: LaunchMode.externalApplication);
      } else {
        // Method 2: Try alternative dialer intent
        const platform = MethodChannel('anxieease.dev/emergency');
        try {
          await platform
              .invokeMethod('makeEmergencyCall', {'number': emergencyNumber});
        } catch (platformError) {
          // Method 3: Show manual dial instructions
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Emergency Call'),
                content: Text(
                  'Please manually dial $emergencyNumber on your phone\'s keypad.\n\n'
                  'Alternative emergency numbers:\n'
                  '• 117 (PNP Emergency Hotline)\n'
                  '• Use your phone\'s emergency call feature',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please manually dial $emergencyNumber'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
