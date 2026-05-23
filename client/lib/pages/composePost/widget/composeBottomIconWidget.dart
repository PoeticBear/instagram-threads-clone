import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

class ComposeBottomIconWidget extends StatelessWidget {
  final Function(File) onImageSelected;

  const ComposeBottomIconWidget({
    Key? key,
    required this.onImageSelected,
  }) : super(key: key);

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (xFile != null) {
      onImageSelected(File(xFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _pickImage,
      icon: Icon(Iconsax.picture_frame, size: 24, color: Colors.white),
    );
  }
}
