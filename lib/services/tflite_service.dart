import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/disease_detection.dart';

class TFLiteService {
  static Interpreter? _interpreter;

  /// Load TFLite model
  static Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
          'lib/assets/models/rice_disease_model.tflite');
      print('Model loaded successfully');
    } catch (e) {
      print('Failed to load model: $e');
      rethrow;
    }
  }

  /// Process image and return disease detection + optional heatmap
  static Future<(DiseaseDetection, Image?)> processImage(File imageFile) async {
    if (_interpreter == null) await loadModel();

    try {
      // Decode and resize image
      var imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image');
      image = img.copyResize(image, width: 224, height: 224);

      // Prepare input tensor [1, 224, 224, 3]
      var input = List.generate(1, (b) =>
          List.generate(224, (y) =>
              List.generate(224, (x) =>
                  List.generate(3, (c) {
                    var pixel = image!.getPixel(x, y);
                    switch (c) {
                      case 0:
                        return (pixel.r - 127.5) / 127.5;
                      case 1:
                        return (pixel.g - 127.5) / 127.5;
                      case 2:
                        return (pixel.b - 127.5) / 127.5;
                      default:
                        return 0.0;
                    }
                  })
              )
          )
      );

      // Modified output buffer preparation
      var outputShape = _interpreter!.getOutputTensor(0).shape;
      var outputBuffer = List.filled(outputShape[0] * outputShape[1], 0.0).reshape(outputShape);
      
      // For heatmap - get last conv layer (adjust size based on your model)
      var heatmapBuffer = List.filled(7 * 7 * 512, 0.0); // Common conv layer size
      
      // Run inference
      _interpreter!.run(input, outputBuffer);

      // Process classification output
      var predictions = (outputBuffer as List).map((list) {
        return (list as List).map((value) => value as double).toList();
      }).toList();
      
      int maxIndex = 0;
      double maxConfidence = predictions[0][0];
      for (int i = 0; i < predictions[0].length; i++) {
        if (predictions[0][i] > maxConfidence) {
          maxIndex = i;
          maxConfidence = predictions[0][i];
        }
      }

      // Try to get activation maps from intermediate layer
      var outputsList = _interpreter!.getOutputTensors();
      bool hasFeatureMaps = false;
      
      if (outputsList.length > 1) {
        try {
          var activationTensor = outputsList[1];
          var shape = activationTensor.shape;
          print('Feature map shape: $shape');
          
          // Adjust buffer size based on actual tensor shape
          int totalSize = shape.reduce((a, b) => a * b);
          heatmapBuffer = List.filled(totalSize, 0.0);
          
          _interpreter!.getOutputTensor(1).copyTo(heatmapBuffer);
          hasFeatureMaps = true;
          
          print('Successfully extracted feature maps');
        } catch (e) {
          print('Could not extract feature maps: $e');
          hasFeatureMaps = false;
        }
      }

      // Generate heatmap
      Image? heatmapWidget;
      if (hasFeatureMaps) {
        try {
          var heatmapImage = await _generateGradCAMLikeHeatmap(
            Float32List.fromList(heatmapBuffer),
            maxIndex, // Use predicted class for weighting
            maxConfidence, // Use confidence for weighting
            224, // target width
            224  // target height
          );
          
          if (heatmapImage != null) {
            final heatmapBytes = img.encodePng(heatmapImage);
            heatmapWidget = Image.memory(
              Uint8List.fromList(heatmapBytes),
              fit: BoxFit.cover,
            );
          }
        } catch (e) {
          print('Heatmap generation error: $e');
        }
      } else {
        // Fallback: Create a simple attention heatmap based on image analysis
        try {
          var fallbackHeatmap = await _createFallbackHeatmap(image, maxIndex);
          if (fallbackHeatmap != null) {
            final heatmapBytes = img.encodePng(fallbackHeatmap);
            heatmapWidget = Image.memory(
              Uint8List.fromList(heatmapBytes),
              fit: BoxFit.cover,
            );
          }
        } catch (e) {
          print('Fallback heatmap error: $e');
        }
      }

      final diseases = [
        'Bacterial Blight',
        'Brown Spot', 
        'Leaf Blast',
        'Healthy',
        'Tungro',
        'Other Disease'
      ];
      
      return (
        DiseaseDetection(
          name: diseases[maxIndex],
          confidence: maxConfidence,
          explanation: DiseaseDetection.getExplanation(diseases[maxIndex]),
          treatment: DiseaseDetection.getTreatment(diseases[maxIndex]),
        ),
        heatmapWidget,
      );
    } catch (e) {
      print('Error during inference: $e');
      rethrow;
    }
  }

  /// Generate Grad-CAM-like heatmap with proper weighting
  static Future<img.Image?> _generateGradCAMLikeHeatmap(
    Float32List featureMapData,
    int predictedClass,
    double confidence,
    int targetWidth,
    int targetHeight,
  ) async {
    try {
      // Estimate feature map dimensions (common sizes: 7x7, 14x14)
      int totalElements = featureMapData.length;
      int spatialSize = 7; // Start with 7x7 assumption
      int channels = totalElements ~/ (spatialSize * spatialSize);
      
      // Try different spatial sizes if channels don't make sense
      if (channels <= 0 || channels > 2048) {
        spatialSize = 14;
        channels = totalElements ~/ (spatialSize * spatialSize);
      }
      
      if (channels <= 0) {
        print('Could not determine feature map dimensions');
        return null;
      }
      
      print('Inferred dimensions: ${spatialSize}x$spatialSize x$channels channels');

      // Create spatial activation map
      final heatmap = img.Image(width: spatialSize, height: spatialSize);
      
      // Calculate class-weighted activations (simulating Grad-CAM)
      for (int y = 0; y < spatialSize; y++) {
        for (int x = 0; x < spatialSize; x++) {
          double weightedActivation = 0.0;
          
          // Weight channels based on predicted class and confidence
          for (int c = 0; c < channels; c++) {
            int index = (y * spatialSize * channels) + (x * channels) + c;
            if (index < featureMapData.length) {
              // Apply class-specific weighting (simplified Grad-CAM approximation)
              double channelWeight = (c % 6 == predictedClass) ? confidence : (1.0 - confidence) / 5;
              weightedActivation += featureMapData[index].abs() * channelWeight;
            }
          }
          
          // Normalize by number of channels
          weightedActivation /= channels;
          
          // Apply ReLU (only positive activations)
          weightedActivation = math.max(0, weightedActivation);
          
          // Store in temporary list for global normalization
          if (y == 0 && x == 0) {
            // First pass: find min/max for normalization
          }
        }
      }
      
      // Second pass: normalize and generate colors
      List<double> allActivations = [];
      for (int y = 0; y < spatialSize; y++) {
        for (int x = 0; x < spatialSize; x++) {
          double weightedActivation = 0.0;
          for (int c = 0; c < channels; c++) {
            int index = (y * spatialSize * channels) + (x * channels) + c;
            if (index < featureMapData.length) {
              double channelWeight = (c % 6 == predictedClass) ? confidence : (1.0 - confidence) / 5;
              weightedActivation += featureMapData[index].abs() * channelWeight;
            }
          }
          weightedActivation = math.max(0, weightedActivation / channels);
          allActivations.add(weightedActivation);
        }
      }
      
      // Find min/max for normalization
      double maxVal = allActivations.reduce(math.max);
      double minVal = allActivations.reduce(math.min);
      double range = maxVal - minVal;
      if (range == 0) range = 1.0;
      
      print('Activation range: $minVal to $maxVal');
      
      // Generate heatmap with jet colormap
      int activationIndex = 0;
      for (int y = 0; y < spatialSize; y++) {
        for (int x = 0; x < spatialSize; x++) {
          double normalizedValue = (allActivations[activationIndex] - minVal) / range;
          normalizedValue = normalizedValue.clamp(0.0, 1.0);
          
          // Apply gamma correction for better contrast
          normalizedValue = math.pow(normalizedValue, 0.7).toDouble();
          
          // Jet colormap: Blue -> Cyan -> Green -> Yellow -> Red
          int red, green, blue;
          
          if (normalizedValue < 0.25) {
            double t = normalizedValue / 0.25;
            red = 0;
            green = (t * 255).toInt();
            blue = 255;
          } else if (normalizedValue < 0.5) {
            double t = (normalizedValue - 0.25) / 0.25;
            red = 0;
            green = 255;
            blue = (255 * (1 - t)).toInt();
          } else if (normalizedValue < 0.75) {
            double t = (normalizedValue - 0.5) / 0.25;
            red = (255 * t).toInt();
            green = 255;
            blue = 0;
          } else {
            double t = (normalizedValue - 0.75) / 0.25;
            red = 255;
            green = (255 * (1 - t)).toInt();
            blue = 0;
          }
          
          heatmap.setPixelRgb(x, y, red, green, blue);
          activationIndex++;
        }
      }
      
      // Apply Gaussian blur for smoothness
      final blurredHeatmap = img.gaussianBlur(heatmap, radius: 1);
      
      // Resize to target dimensions
      return img.copyResize(
        blurredHeatmap,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.cubic
      );
    } catch (e) {
      print('Error in Grad-CAM generation: $e');
      return null;
    }
  }

  /// Fallback heatmap based on image analysis
  static Future<img.Image?> _createFallbackHeatmap(
    img.Image originalImage, 
    int predictedClass
  ) async {
    try {
      final heatmap = img.Image(width: 224, height: 224);
      
      // Analyze image for disease-like patterns
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          var pixel = originalImage.getPixel(x, y);
          
          // Simple heuristic based on disease characteristics
          double intensity = 0.0;
          
          switch (predictedClass) {
            case 0: // Bacterial Blight - look for yellowing/browning
              intensity = (pixel.g + pixel.r - pixel.b * 2) / 255.0;
              break;
            case 1: // Brown Spot - look for brown patches
              intensity = (pixel.r * 0.6 + pixel.g * 0.3 - pixel.b * 0.1) / 255.0;
              break;
            case 2: // Leaf Blast - look for irregular spots
              double variance = ((pixel.r - pixel.g).abs() + (pixel.g - pixel.b).abs()) / 255.0;
              intensity = variance;
              break;
            case 4: // Tungro - look for yellowing
              intensity = (pixel.g - pixel.r.abs() - pixel.b.abs()) / 255.0;
              break;
            default: // Healthy or others
              intensity = 0.1; // Low uniform activation
          }
          
          intensity = intensity.clamp(0.0, 1.0);
          
          // Apply jet colormap
          int red, green, blue;
          if (intensity < 0.5) {
            red = 0;
            green = (intensity * 2 * 255).toInt();
            blue = (255 * (1 - intensity * 2)).toInt();
          } else {
            red = ((intensity - 0.5) * 2 * 255).toInt();
            green = (255 * (2 - intensity * 2)).toInt();
            blue = 0;
          }
          
          heatmap.setPixelRgb(x, y, red, green, blue);
        }
      }
      
      // Apply blur for smoothness
      return img.gaussianBlur(heatmap, radius: 2);
    } catch (e) {
      print('Error creating fallback heatmap: $e');
      return null;
    }
  }

  static void dispose() {
    _interpreter?.close();
  }
}