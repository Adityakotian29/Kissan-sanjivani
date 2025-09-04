import 'package:flutter/foundation.dart';

@immutable
class DiseaseDetection {
  final String name;
  final double confidence;
  final String explanation;
  final String treatment;
  final DateTime detectedAt;

   DiseaseDetection({
    required this.name,
    required this.confidence,
    required this.explanation,
    required this.treatment,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  // Add disease explanations
  static String getExplanation(String diseaseName) {
    final explanations = {
      'Bacterial Blight': '''
        Bacterial blight is a serious rice disease caused by Xanthomonas oryzae.
        Symptoms include water-soaked lesions that turn yellow and then grayish white.
        The disease can severely affect yield, especially in susceptible varieties.
      ''',
      'Brown Spot': '''
        Brown spot disease is caused by the fungus Cochliobolus miyabeanus.
        It appears as brown, oval-shaped spots on leaves and can affect all growth stages.
        The disease is more severe in nutrient-deficient soils and stressed conditions.
      ''',
      'Leaf Blast': '''
        Leaf blast is caused by the fungus Magnaporthe oryzae.
        Symptoms include diamond-shaped lesions with gray centers and brown borders.
        It's one of the most devastating rice diseases worldwide.
      ''',
      'Healthy': '''
        The plant appears to be healthy with no visible signs of disease.
        Continue maintaining good agricultural practices to keep the plant healthy.
      ''',
      'Other Disease': '''
        The symptoms don't match common rice diseases.
        Consider consulting a local agricultural expert for proper diagnosis.
      ''',
      'Tungro': '''
        Rice Tungro disease is caused by a combination of two viruses.
        Symptoms include yellowing and orange-colored leaves, stunted growth, and reduced tillering.
        The disease is transmitted by green leafhoppers and can cause severe yield losses.
        Early detection and management is crucial for preventing crop damage.
      ''',
    };

    return explanations[diseaseName] ?? 'No explanation available for this disease.';
  }

  // Add treatment recommendations
  static String getTreatment(String diseaseName) {
    final treatments = {
      'Bacterial Blight': '''
        1. Use disease-resistant rice varieties
        2. Apply copper-based bactericides
        3. Maintain proper field drainage
        4. Remove infected plants and debris
        5. Practice crop rotation
      ''',
      'Brown Spot': '''
        1. Apply balanced fertilization
        2. Use fungicides (propiconazole or hexaconazole)
        3. Maintain optimal spacing between plants
        4. Ensure proper irrigation
        5. Remove infected plant debris
      ''',
      'Leaf Blast': '''
        1. Apply systemic fungicides
        2. Reduce nitrogen fertilization
        3. Maintain consistent water levels
        4. Plant resistant varieties
        5. Avoid dense canopy
      ''',
      'Healthy': '''
        1. Continue regular monitoring
        2. Maintain proper nutrition
        3. Follow recommended irrigation practices
        4. Keep field clean and well-maintained
      ''',
      'Other Disease': '''
        1. Isolate affected plants
        2. Document symptoms carefully
        3. Consult agricultural extension services
        4. Send samples for laboratory testing
      ''',
      'Tungro': '''
        1. Remove infected plants immediately to prevent spread
        2. Control leafhopper populations using appropriate insecticides
        3. Plant resistant varieties when available
        4. Adjust planting times to avoid peak leafhopper seasons
        5. Maintain proper spacing between plants
        6. Keep fields clean of weeds that may host the virus
        7. Monitor regularly for early signs of infection
      ''',
    };

    return treatments[diseaseName] ?? 'No specific treatment available for this disease.';
  }

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'confidence': confidence,
      'explanation': explanation,
      'treatment': treatment,
      'detectedAt': detectedAt.toIso8601String(),
    };
  }

  // Create from Map for retrieval
  factory DiseaseDetection.fromMap(Map<String, dynamic> map) {
    return DiseaseDetection(
      name: map['name'] as String,
      confidence: map['confidence'] as double,
      explanation: map['explanation'] as String,
      treatment: map['treatment'] as String,
      detectedAt: DateTime.parse(map['detectedAt'] as String),
    );
  }
}