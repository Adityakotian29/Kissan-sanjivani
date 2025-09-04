import 'dart:io';
import 'package:image/image.dart' as img;

class HeatmapService {
  static Future<img.Image> generateHeatmap(File imageFile, List<double> predictions) async {
    // Load and decode the original image
    final bytes = await imageFile.readAsBytes();
    final originalImage = img.decodeImage(bytes)!;
    
    // Create a new image for the heatmap
    final heatmapImage = img.Image(
      width: originalImage.width,
      height: originalImage.height,
    );
    
    // Generate heatmap based on model predictions
    for (int y = 0; y < originalImage.height; y++) {
      for (int x = 0; x < originalImage.width; x++) {
        // Normalize coordinates to prediction array size
        final predIndex = (y * predictions.length ~/ originalImage.height).clamp(
          0,
          predictions.length - 1
        );
        
        double intensity = predictions[predIndex];
        
        // Create color using img package methods
        final color = img.ColorUint8.rgba(
          (255 * intensity).round(),  // Red channel
          0,                          // Green channel
          0,                          // Blue channel
          128                         // Alpha channel
        );
        
        heatmapImage.setPixelRgba(
          x,
          y,
          color.r,
          color.g,
          color.b,
          color.a,
        );
      }
    }
    
    // Blend heatmap with original image
    // Create a copy of the original image
    final resultImage = img.copyResize(originalImage, width: originalImage.width, height: originalImage.height);
    
    // Blend the heatmap with alpha
    img.compositeImage(
      resultImage,
      heatmapImage,
      dstX: 0,
      dstY: 0,
      blend: img.BlendMode.alpha,
    );
    
    return resultImage;
  }
}