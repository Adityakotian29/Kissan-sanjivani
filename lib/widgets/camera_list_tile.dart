import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraListTile extends StatelessWidget {
  final Function(ImageSource) onImageSourceSelected;

  const CameraListTile({Key? key, required this.onImageSourceSelected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.camera_alt, color: Colors.blue),
      title: const Text("Camera"),
      onTap: () {
        Navigator.pop(context);
        onImageSourceSelected(ImageSource.camera);
      },
    );
  }
}