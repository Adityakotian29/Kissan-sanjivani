import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/detection_provider.dart';
import '../widgets/image_source_dialog.dart';
import '../widgets/detection_result_card.dart';
import '../services/tflite_service.dart';
import '../models/disease_detection.dart';

class ImagePickerScreen extends ConsumerStatefulWidget {
  const ImagePickerScreen({super.key});

  @override
  ConsumerState<ImagePickerScreen> createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends ConsumerState<ImagePickerScreen> with TickerProviderStateMixin {
  File? _imageFile;
  String? _imageFileName;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  Image? _heatmapImage;
  String? _diseaseName;
  String? _confidenceScore;
  String? _explanation;
  String? _recommendedAction;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      var status = await Permission.camera.request();
      if (!status.isGranted) {
        _showSnackBar("Camera permission denied", Icons.camera_alt, Colors.red);
        return;
      }
    } else {
      if (Platform.isAndroid) {
        if (await Permission.photos.request().isGranted ||
            await Permission.storage.request().isGranted ||
            await Permission.mediaLibrary.request().isGranted) {
          // Permission granted
        } else {
          _showSnackBar("Gallery access denied", Icons.photo_library, Colors.red);
          return;
        }
      }
    }

    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _imageFileName = pickedFile.name;
        _diseaseName = null;
        _confidenceScore = null;
        _explanation = null;
        _recommendedAction = null;
      });
      _animationController.forward();
    } else {
      _showSnackBar("No image selected", Icons.image, Colors.orange);
    }
  }

  Future<void> _detectDisease() async {
    if (_imageFile == null) {
      _showSnackBar("Please select an image first", Icons.warning, Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final (detection, heatmap) = await TFLiteService.processImage(_imageFile!);
      
      ref.read(detectionProvider.notifier).setDetection(detection);
      
      setState(() {
        _heatmapImage = heatmap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ref.read(detectionProvider.notifier).reset(); // Reset detection if error occurs
      _showSnackBar("Error processing image: $e", Icons.error, Colors.red);
    }
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String getExplanationForDisease(String disease) {
    // Create a map of disease explanations
    final explanations = {
      'Bacterial Blight': 'Bacterial blight is characterized by...',
      'Brown Spot': 'Brown spot disease appears as...',
      // Add more diseases and explanations
    };
    
    return explanations[disease] ?? 'No explanation available for this disease.';
  }

  String getTreatmentForDisease(String disease) {
    // Create a map of disease treatments
    final treatments = {
      'Bacterial Blight': 'Use disease-resistant varieties...',
      'Brown Spot': 'Apply fungicides and maintain proper...',
      // Add more diseases and treatments
    };
    
    return treatments[disease] ?? 'No treatment recommendation available.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.eco,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'KissanSanjivani',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.green,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.green.withOpacity(0.1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.agriculture,
                    size: 40,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'AI-Powered Disease Detection',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Upload a photo of your plant for instant analysis',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Image Display Section
            if (_imageFile != null)
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(
                            _imageFile!,
                            width: double.infinity,
                            height: 250,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _imageFileName ?? "Image uploaded successfully",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _detectDisease,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 5,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.search, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Detect Disease',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              )
            else
              // Empty State
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'No image selected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload an image to get started',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Select Image Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => showImageSourceDialog(context, _pickImage),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: const BorderSide(color: Colors.green, width: 2),
                  ),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Select Image',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Results Section
            if (ref.watch(detectionProvider).value != null && _imageFile != null)
              DetectionResultCard(
                detection: ref.watch(detectionProvider).value!,
                imageFile: _imageFile!,
                heatmapImage: _heatmapImage,
              ),
          ],
        ),
      ),
    );
  }
}