import 'package:flutter/material.dart';
import 'models/psychologist_model.dart';
import 'services/supabase_service.dart';
import 'psychologist_profile.dart';
import 'utils/logger.dart';

class PsychologistListScreen extends StatefulWidget {
  const PsychologistListScreen({super.key});

  @override
  State<PsychologistListScreen> createState() => _PsychologistListScreenState();
}

class _PsychologistListScreenState extends State<PsychologistListScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<PsychologistModel> _psychologists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPsychologists();
  }

  Future<void> _loadPsychologists() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _supabaseService.getAllPsychologists();
      setState(() {
        _psychologists =
            result.map((data) => PsychologistModel.fromJson(data)).toList();
      });
    } catch (e) {
      Logger.error('Error loading psychologists', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading psychologists: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _assignPsychologist(String psychologistId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _supabaseService.assignPsychologist(psychologistId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Psychologist assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const PsychologistProfilePage(),
          ),
        );
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3AA772)))
          : _psychologists.isEmpty
              ? const Center(
                  child: Text(
                    'No psychologists available at this time',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _psychologists.length,
                  itemBuilder: (context, index) {
                    final psychologist = _psychologists[index];
                    return _buildPsychologistCard(psychologist);
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
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF3AA772).withOpacity(0.1),
                  backgroundImage: psychologist.imageUrl != null
                      ? NetworkImage(psychologist.imageUrl!)
                      : null,
                  child: psychologist.imageUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 30,
                          color: Color(0xFF3AA772),
                        )
                      : null,
                ),
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
