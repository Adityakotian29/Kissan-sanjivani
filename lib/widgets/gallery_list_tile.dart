import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class GalleryListTile extends StatelessWidget {
  final Function(ImageSource) onImageSourceSelected;

  const GalleryListTile({Key? key, required this.onImageSourceSelected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.photo, color: Colors.green),
      title: const Text("Gallery"),
      onTap: () {
        Navigator.pop(context);
        onImageSourceSelected(ImageSource.gallery);
      },
    );
  }
}