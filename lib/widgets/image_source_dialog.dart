import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_list_tile.dart';
import 'gallery_list_tile.dart';

void showImageSourceDialog(BuildContext context, Function(ImageSource) onImageSourceSelected) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text(
        "Select Image Source",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CameraListTile(onImageSourceSelected: onImageSourceSelected),
          const Divider(),
          GalleryListTile(onImageSourceSelected: onImageSourceSelected),
        ],
      ),
    ),
  );
}