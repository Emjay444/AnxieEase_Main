import 'package:flutter/material.dart';
import 'models/psychologist_model.dart';
import 'services/supabase_service.dart';
import 'utils/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PsychologistListScreen extends StatefulWidget {
  const PsychologistListScreen({super.key});

  @override
  State<PsychologistListScreen> createState() => _PsychologistListScreenState();
}

class _PsychologistListScreenState extends State<PsychologistListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  late Future<List<PsychologistModel>> _futurePsychologists;

  @override
  void initState() {
    super.initState();
    _futurePsychologists = _fetchPsychologists();
  }

  Future<List<PsychologistModel>> _fetchPsychologists() async {
    try {
      final result = await _supabaseService.getAllPsychologists();
      return result.map((data) => PsychologistModel.fromJson(data)).toList();
    } catch (e) {
      Logger.error('Error loading psychologists', e);
      rethrow;
    }
  }

  Future<void> _assignPsychologist(String psychologistId) async {
    try {
      // Show a modal progress indicator without rebuilding the entire list
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF3AA772)),
        ),
      );
      await _supabaseService.assignPsychologist(psychologistId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Psychologist assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Return to previous screen and signal that a change occurred
        Navigator.pop(context, true);
      }
    } catch (e) {
      Logger.error('Error assigning psychologist', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning psychologist: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Available Psychologists',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF3AA772),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<PsychologistModel>>(
        future: _futurePsychologists,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF3AA772)));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    const Text('Failed to load psychologists'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _futurePsychologists = _fetchPsychologists();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3AA772),
                        foregroundColor: Colors.white,
                      ),
                    )
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return const Center(
              child: Text(
                'No psychologists available at this time',
                style: TextStyle(fontSize: 16),
              ),
            );
          }
          return ScrollConfiguration(
            behavior: const _NoGlowBehavior(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              itemBuilder: (context, index) {
                return _buildPsychologistCard(data[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPsychologistCard(PsychologistModel psychologist) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(imageUrl: psychologist.imageUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        psychologist.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        psychologist.specialization,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.email_outlined,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              psychologist.contactEmail,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            psychologist.contactPhone,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Biography',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              psychologist.biography,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _assignPsychologist(psychologist.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3AA772),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Select This Psychologist'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom avatar with caching & shimmer
class _Avatar extends StatelessWidget {
  final String? imageUrl;
  const _Avatar({required this.imageUrl});
  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: 60,
        height: 60,
        color: const Color(0xFF3AA772).withOpacity(0.08),
        child: imageUrl == null || imageUrl!.isEmpty
            ? const Icon(Icons.person, size: 30, color: Color(0xFF3AA772))
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (c, _) => const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (c, _, __) => const Icon(Icons.person,
                    size: 30, color: Color(0xFF3AA772)),
              ),
      ),
    );
  }
}

// Remove overscroll glow (slight perf & UX polish)
class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
