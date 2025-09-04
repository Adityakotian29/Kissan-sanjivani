import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/disease_detection.dart';
import 'dart:io';

class DetectionResultCard extends ConsumerWidget {
  final DiseaseDetection detection;
  final File imageFile;
  final Image? heatmapImage;

  const DetectionResultCard({
    required this.detection,
    required this.imageFile,
    this.heatmapImage,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image and Heatmap Stack
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.file(
                  imageFile,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              if (heatmapImage != null)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Stack(
                        children: [
                          // Heatmap with blend mode for better integration
                          ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.multiply,
                            ),
                            child: Opacity(
                              opacity: 0.6, // Adjusted opacity for better visibility
                              child: heatmapImage!,
                            ),
                          ),
                          // Optional: Add a subtle overlay to enhance the heatmap effect
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.1),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Heatmap indicator
              if (heatmapImage != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AI Focus Areas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResultSection(
                  'Disease Detected',
                  detection.name,
                  Icons.local_hospital,
                  Colors.red,
                ),
                _buildResultSection(
                  'Confidence Score',
                  '${(detection.confidence * 100).toStringAsFixed(1)}%',
                  Icons.analytics,
                  Colors.blue,
                ),
                _buildResultSection(
                  'AI Explanation',
                  detection.explanation,
                  Icons.psychology,
                  Colors.purple,
                ),
                _buildResultSection(
                  'Recommended Treatment',
                  detection.treatment,
                  Icons.healing,
                  Colors.green,
                ),
                
                // Heatmap explanation
                if (heatmapImage != null)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Heatmap Explanation',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'The colored overlay shows areas the AI focused on when making its prediction. '
                          'Red/yellow areas indicate high attention, blue areas indicate low attention.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection(String title, String content, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}