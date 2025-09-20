import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  State<AnxietyConfirmationDialog> createState() => _AnxietyConfirmationDialogState();
}

class _AnxietyConfirmationDialogState extends State<AnxietyConfirmationDialog> with SingleTickerProviderStateMixin {
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

  Color _getConfidenceColor() {
    if (widget.confidenceLevel >= 0.8) return Colors.red;
    if (widget.confidenceLevel >= 0.6) return Colors.orange;
    return Colors.blue;
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

      if (mounted) {
        // Return the response data to the caller
        Navigator.of(context).pop({
          'confirmed': _selectedResponse == 'yes',
          'severity': _selectedSeverity,
          'response': _selectedResponse,
        });
        
        // Navigate to appropriate help screen based on response
        if (_selectedResponse == 'yes') {
          _showHelpOptions();
        } else {
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

  void _showHelpOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.favorite, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('We\'re Here to Help'),
          ],
        ),
        content: const Text(
          'Thank you for confirming. Would you like to try some techniques to help manage your anxiety?'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/breathing');
            },
            child: const Text('Breathing Exercise'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/grounding');
            },
            child: const Text('Grounding Technique'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not Now'),
          ),
        ],
      ),
    );
  }

  void _showThankYouMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you for the feedback! We\'ll continue monitoring.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confidenceColor = _getConfidenceColor();
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
                confidenceColor.withOpacity(0.1),
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
                      confidenceColor.withOpacity(0.12),
                      confidenceColor.withOpacity(0.08),
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
                      color: confidenceColor,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: confidenceColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: confidenceColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$confidencePercent% Confidence',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: confidenceColor,
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
                        color: confidenceColor,
                        backgroundColor: confidenceColor.withOpacity(0.12),
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
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // Main question
                    const Text(
                      'Are you currently feeling anxious or stressed?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildSeverityChip('Mild', Colors.green),
                          _buildSeverityChip('Moderate', Colors.orange),
                          _buildSeverityChip('Severe', Colors.red),
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
                    Text(
                      'Your response helps us improve detection accuracy and provide better support.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
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
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Later'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (
                                  _selectedResponse != null &&
                                  !(_selectedResponse == 'yes' && _selectedSeverity == null) &&
                                  !_isSubmitting)
                              ? _submitResponse
                              : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: confidenceColor,
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
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

  Widget _buildResponseButton(String label, String value, Color color, IconData icon) {
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
}