import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:threads/theme/app_colors.dart';

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
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return IconButton(
      onPressed: _pickImage,
      icon: Icon(Iconsax.picture_frame, size: 24, color: appColors.textPrimary),
    );
  }
}
