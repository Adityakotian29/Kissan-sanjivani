import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/disease_detection.dart';

final detectionProvider = StateNotifierProvider<DetectionNotifier, AsyncValue<DiseaseDetection?>>((ref) {
  return DetectionNotifier();
});

class DetectionNotifier extends StateNotifier<AsyncValue<DiseaseDetection?>> {
  DetectionNotifier() : super(const AsyncValue.data(null));

  void setDetection(DiseaseDetection detection) {
    state = AsyncValue.data(detection);
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}