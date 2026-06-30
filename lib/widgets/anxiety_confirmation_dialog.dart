import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/supabase_service.dart';

/// Dialog shown when anxiety is detected and requires user confirmation
class AnxietyConfirmationDialog extends StatefulWidget {
  final String title;
  final String message;
  final double confidenceLevel;
  final Map<String, dynamic> detectionData;

  const AnxietyConfirmationDialog({
    Key? key,
    required this.title,
    required this.message,
    required this.confidenceLevel,
    required this.detectionData,
  }) : super(key: key);

  @override
  State<AnxietyConfirmationDialog> createState() =>
      _AnxietyConfirmationDialogState();
}

class _AnxietyConfirmationDialogState extends State<AnxietyConfirmationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  String? _selectedResponse;
  String? _selectedSeverity;
  bool _isSubmitting = false;

  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  static const _validSeverities = {'mild', 'moderate', 'severe', 'critical'};

  // Determine severity, preferring the structured `detectionData['severity']`
  // field (sourced from the backend's severity calculation, the
  // `[severity]` message prefix, or the FCM/local-notification payload --
  // see notifications_screen.dart's `_determineSeverity`, which this
  // mirrors) over title/message keyword matching. Title/message parsing is
  // kept only as a fallback for legacy notifications that predate the
  // structured field, so it must never override a structured value that's
  // actually present.
  String _getSeverity() {
    final structured =
        widget.detectionData['severity']?.toString().toLowerCase();
    if (structured != null && _validSeverities.contains(structured)) {
      return structured;
    }

    // Legacy fallback: extract from title text.
    final title1 =
        (widget.detectionData['title']?.toString() ?? '').toLowerCase();
    final title2 = widget.title.toLowerCase();
    final combinedTitle = '$title1 $title2';

    if (combinedTitle.contains('critical')) {
      return 'critical';
    } else if (combinedTitle.contains('severe') ||
        combinedTitle.contains('are you okay')) {
      return 'severe';
    } else if (combinedTitle.contains('moderate') ||
        combinedTitle.contains('checking in')) {
      return 'moderate';
    } else if (combinedTitle.contains('mild') ||
        combinedTitle.contains('gentle')) {
      return 'mild';
    }

    // Legacy fallback: extract from a `[severity]` message prefix.
    final message =
        (widget.detectionData['message']?.toString() ?? widget.message)
            .toLowerCase();
    if (message.contains('[critical]')) {
      return 'critical';
    } else if (message.contains('[severe]')) {
      return 'severe';
    } else if (message.contains('[moderate]')) {
      return 'moderate';
    } else if (message.contains('[mild]')) {
      return 'mild';
    }

    return 'mild';
  }

  // NEW: Map severity to accent/background color (modal scheme)
  // mild=green, moderate=yellow, severe=orange, critical=red
  Color _colorForSeverity(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'severe':
        return Colors.orange;
      case 'moderate':
        return Colors.yellow;
      case 'mild':
      default:
        return Colors.green;
    }
  }

  // REPLACED: Background color based on severity (not confidence)
  Color _getModalBackgroundColor() {
    return _colorForSeverity(_getSeverity());
  }

  // UPDATED: Build a simple severity-based title
  String _getCleanTitle() {
    final severity = _getSeverity();
    // Just show the severity level - simple and clear
    return severity.toUpperCase();
  }

  IconData _getConfidenceIcon() {
    if (widget.confidenceLevel >= 0.8) return Icons.warning_amber_rounded;
    if (widget.confidenceLevel >= 0.6) return Icons.help_outline;
    return Icons.info_outline;
  }

  Future<void> _submitResponse() async {
    if (_selectedResponse == null) return;
    // If user confirmed anxiety, require a severity selection
    if (_selectedResponse == 'yes' && _selectedSeverity == null) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a severity level before submitting.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.lightImpact();

    try {
      // Record user's response to the anxiety detection
      await _supabaseService.recordAnxietyResponse(
        detectionData: widget.detectionData,
        userConfirmed: _selectedResponse == 'yes',
        reportedSeverity: _selectedSeverity,
        confidenceLevel: widget.confidenceLevel,
        responseTime: DateTime.now().toIso8601String(),
      );

      // Update rate limiting based on user confirmation
      await _updateRateLimitingForConfirmation(
        _selectedResponse!,
        _selectedSeverity ?? 'mild',
        widget.detectionData['notification_id']?.toString(),
      );

      if (mounted) {
        // Return the response data to the caller
        Navigator.of(context).pop({
          'confirmed': _selectedResponse == 'yes',
          'severity': _selectedSeverity,
          'response': _selectedResponse,
        });

        // Navigate to appropriate help screen based on response
        // Note: Help modal is now handled by the parent (notifications_screen.dart)
        // so we don't show it here to avoid duplicate modals
        if (_selectedResponse == 'no') {
          _showThankYouMessage();
        }
      }
    } catch (e) {
      debugPrint('Error submitting anxiety response: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to record response. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // Removed _showHelpOptions() - now handled by parent notifications_screen.dart

  // Honest, non-promising copy: this dialog cannot currently guarantee a
  // reduced alert frequency (see _updateRateLimitingForConfirmation), so
  // it must never claim one. It only confirms what actually happened:
  // the response was logged and no anxiety_records row was created.
  void _showThankYouMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Thanks for confirming. This was recorded as a false alarm -- no anxiety record was created.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modalBackgroundColor = _getModalBackgroundColor();
    // NEW: Severity + accent color for UI elements
    final severity = _getSeverity();
    final accentColor = _colorForSeverity(severity);
    final cleanTitle = _getCleanTitle();
    final confidenceIcon = _getConfidenceIcon();
    final confidencePercent = (widget.confidenceLevel * 100).toStringAsFixed(0);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                modalBackgroundColor.withOpacity(0.1),
                Colors.white,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      // use severity accent, not confidence
                      accentColor.withOpacity(0.12),
                      accentColor.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      confidenceIcon,
                      color: Colors.black54, // Subtle black icon
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      cleanTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black, // Always black text
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$confidencePercent% Confidence',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Confidence bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: widget.confidenceLevel.clamp(0.0, 1.0),
                        minHeight: 6,
                        color: accentColor,
                        backgroundColor: accentColor.withOpacity(0.12),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      widget.message,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Main question
                    const Text(
                      'Are you feeling anxious, stressed, or maybe a bit of both right now?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Yes/No buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildResponseButton(
                            'Yes',
                            'yes',
                            Colors.red,
                            Icons.sentiment_very_dissatisfied,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildResponseButton(
                            'No',
                            'no',
                            Colors.green,
                            Icons.sentiment_satisfied,
                          ),
                        ),
                      ],
                    ),

                    // Severity selection (only if yes selected)
                    if (_selectedResponse == 'yes') ...[
                      const SizedBox(height: 20),
                      const Text(
                        'How would you rate your current anxiety level?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildSeverityChip('Mild', Colors.green),
                          _buildSeverityChip('Moderate', Colors.yellow),
                          _buildSeverityChip('Severe', Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _selectedSeverity == null
                              ? 'Select one to enable Submit'
                              : 'Selected: ${_selectedSeverity!.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _selectedSeverity == null
                                ? Colors.orange[700]
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Removed: "Your response helps us improve..." text
                  ],
                ),
              ),

              // Action buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Later'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_selectedResponse != null &&
                                !(_selectedResponse == 'yes' &&
                                    _selectedSeverity == null) &&
                                !_isSubmitting)
                            ? _submitResponse
                            : null,
                        style: ElevatedButton.styleFrom(
                          // use severity accent for call-to-action
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponseButton(
      String label, String value, Color color, IconData icon) {
    final isSelected = _selectedResponse == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedResponse = value;
          if (value == 'no') _selectedSeverity = null;
        });
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey.shade600,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityChip(String label, Color color) {
    final isSelected = _selectedSeverity == label.toLowerCase();
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedSeverity = selected ? label.toLowerCase() : null;
        });
        HapticFeedback.selectionClick();
      },
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      side: BorderSide(color: isSelected ? color : Colors.grey.shade300),
    );
  }

  /// Best-effort attempt to extend the backend's confirmation-aware
  /// cooldown (functions/src/enhancedRateLimiting.ts's
  /// handleUserConfirmationResponse). This call currently CANNOT succeed
  /// from this app: that Cloud Function requires a Firebase Auth context
  /// (`context.auth`), but this app authenticates exclusively via Supabase
  /// Auth and has no Firebase Auth integration at all -- every invocation
  /// throws "unauthenticated" and is swallowed below.
  ///
  /// Deliberately silent and side-effect-free on the UI: no SnackBar here
  /// is gated on this call's result, so this dialog can never show the
  /// user a cooldown/reduced-alert promise that didn't actually happen.
  /// User-facing feedback for "no"/"yes" lives in _showThankYouMessage()
  /// and _submitResponse() instead, and is honest regardless of whether
  /// this call succeeds. If a Supabase-auth-compatible confirmation
  /// endpoint is added later, this is the place to call it.
  Future<void> _updateRateLimitingForConfirmation(
    String response,
    String severity,
    String? notificationId,
  ) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable =
          functions.httpsCallable('handleUserConfirmationResponse');

      final result = await callable.call({
        'severity': severity,
        'response': response,
        'notificationId': notificationId,
      });

      debugPrint('✅ Rate limiting updated: ${result.data}');
    } catch (e) {
      debugPrint(
          'ℹ️ Backend cooldown update unavailable (expected -- see method doc): $e');
      // Don't show error to user - this is a background, best-effort
      // operation with no user-visible promise attached to its outcome.
    }
  }
}
