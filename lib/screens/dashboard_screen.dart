// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_section_header.dart';
import '../widgets/gradient_background.dart';
import 'video_player_screen.dart';

// --- Models (unchanged) ---
class Exercise {
  final String exerciseName;
  final String? exerciseUrl;

  Exercise({required this.exerciseName, this.exerciseUrl});

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      exerciseName: json['exercise_name'] ?? 'Unnamed exercise',
      exerciseUrl: json['exercise_url'],
    );
  }
}

class Prescription {
  final int id;
  final String createdAt;
  final String status;
  final String? notes;
  final List<Exercise> exercises;

  Prescription({
    required this.id,
    required this.createdAt,
    required this.status,
    this.notes,
    required this.exercises,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      id: json['id'],
      createdAt: json['created_at'] ?? '',
      status: json['status'] ?? 'active',
      notes: json['prescription_notes'],
      exercises: (json['exercises'] as List<dynamic>? ?? [])
          .map((e) => Exercise.fromJson(e))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// DASHBOARD SCREEN – light healthcare style (white cards on soft blue wash)
// ---------------------------------------------------------------------------
class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> patientData;

  const DashboardScreen({super.key, required this.patientData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final patientName = widget.patientData['patient_name'] ?? 'Patient';
    final diagnosis = widget.patientData['diagnosis'] ?? 'Not specified';
    final rawPrescription = widget.patientData['latest_prescription'];

    final Prescription? prescription = rawPrescription != null
        ? Prescription.fromJson(rawPrescription)
        : null;

    final exerciseCount = prescription?.exercises.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Exercises'),
      ),
      body: GradientBackground(
        padding: EdgeInsets.zero,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            // Patient header card
            CustomSectionHeader(
              patientName: patientName,
              diagnosis: diagnosis,
            ),
            const SizedBox(height: 24),

            // Section title with count chip
            if (prescription != null && exerciseCount > 0) ...[
              Row(
                children: [
                  Text(
                    'Prescribed Exercises',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$exerciseCount',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            if (prescription == null)
              _buildEmptyState()
            else ...[
              _buildExerciseFeed(prescription.exercises),
              if (prescription.notes != null &&
                  prescription.notes!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildNotesCard(prescription.notes!),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return CustomCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'No Prescriptions Yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'You do not have any exercise prescriptions assigned right now.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseFeed(List<Exercise> exercises) {
    if (exercises.isEmpty) {
      return CustomCard(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No exercises assigned.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    // Resolve every exercise to a playable item once, so the player can carry
    // the whole prescription as a playlist (enables auto-advance in M4) and the
    // feed can show real YouTube thumbnails.
    final playlist = exercises
        .map((e) => ExerciseVideo.fromUrl(e.exerciseName, e.exerciseUrl))
        .toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: exercises.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) =>
          _buildFeedItem(playlist[index], playlist, index),
    );
  }

  void _openPlayer(List<ExerciseVideo> playlist, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          playlist: playlist,
          initialIndex: index,
        ),
      ),
    );
  }

  // --- Light card: thumbnail with play overlay + title below ---
  Widget _buildFeedItem(
    ExerciseVideo item,
    List<ExerciseVideo> playlist,
    int index,
  ) {
    return CustomCard(
      padding: EdgeInsets.zero,
      onTap: () => _openPlayer(playlist, index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Thumbnail with rounded top corners + play badge ---
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.thumbnailUrl != null)
                    Image.network(
                      item.thumbnailUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: const Color(0xFFEDF3FA),
                          child: const Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                    )
                  else
                    _thumbPlaceholder(),
                  // Soft gradient so the play button always reads
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),
                  // Play badge
                  Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Icon(
                          item.hasVideo
                              ? Icons.play_arrow_rounded
                              : Icons.zoom_out_map_rounded,
                          color: AppColors.primary,
                          size: 34),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // --- Title row ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: const Color(0xFFEDF3FA),
      child: const Icon(Icons.fitness_center_rounded,
          color: AppColors.primaryLight, size: 40),
    );
  }

  Widget _buildNotesCard(String notes) {
    return CustomCard(
      color: AppColors.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sticky_note_2_outlined,
                  color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Prescription Notes',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            notes,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
