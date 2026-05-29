import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/theme/app_colors.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _displayName;
  late TextEditingController _bio;
  late TextEditingController _link;
  late TextEditingController _pronouns;
  late TextEditingController _location;
  File? _image;
  int _selectedGender = 1; // 1=Not set, 2=Male, 3=Female, 4=Other
  bool _isPrivate = false;
  int _accountType = 1; // 1=Personal, 2=Creator, 3=Business

  @override
  void initState() {
    super.initState();
    final state = Provider.of<AuthState>(context, listen: false);
    _displayName = TextEditingController(text: state.userModel?.displayName ?? '');
    _bio = TextEditingController(text: state.userModel?.bio ?? '');
    _link = TextEditingController(text: state.userModel?.link ?? '');
    _pronouns = TextEditingController(text: state.userModel?.pronouns ?? '');
    _location = TextEditingController(text: state.userModel?.location ?? '');
    _selectedGender = state.userModel?.gender ?? 1;
    _isPrivate = state.userModel?.isPrivate ?? false;
    _accountType = state.userModel?.accountType ?? 1;
  }

  @override
  void dispose() {
    _bio.dispose();
    _link.dispose();
    _displayName.dispose();
    _pronouns.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> getImage(BuildContext context, ImageSource source,
      Function(File) onImageSelected) async {
    ImagePicker()
        .pickImage(source: source, imageQuality: 100)
        .then((XFile? file) async {
      if (file != null) {
        onImageSelected(File(file.path));
      }
    });
  }

  String _genderLabel(int value) {
    switch (value) {
      case 2: return 'Male';
      case 3: return 'Female';
      case 4: return 'Other';
      default: return 'Not set';
    }
  }

  String _accountTypeLabel(int value) {
    switch (value) {
      case 2: return 'Creator';
      case 3: return 'Business';
      default: return 'Personal';
    }
  }

  @override
  Widget build(BuildContext context) {
    var state = Provider.of<AuthState>(context);
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
        backgroundColor: appColors.background,
        appBar: AppBar(
          toolbarHeight: 68,
          leading: Container(),
          flexibleSpace: Padding(
              padding: EdgeInsets.only(left: 5, top: 60),
              child: Container(
                  decoration: BoxDecoration(
                      color: appColors.surfaceTertiary,
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(15),
                          topRight: Radius.circular(15))),
                  height: 50,
                  width: MediaQuery.of(context).size.width,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeIn(
                          duration: Duration(milliseconds: 1000),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                  padding: EdgeInsets.only(left: 15, top: 5),
                                  child: GestureDetector(
                                      onTap: () {
                                        Navigator.pop(context);
                                      },
                                      child: Text("Cancel",
                                          style: TextStyle(
                                              color: appColors.textPrimary,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w400)))),
                              Text(
                                "Edit profile   ",
                                style: TextStyle(
                                    color: appColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700),
                              ),
                              Padding(
                                padding: EdgeInsets.only(right: 15),
                                child: GestureDetector(
                                    onTap: _submitButton,
                                    child: Text("Done",
                                        style: TextStyle(
                                            color: appColors.accent,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600))),
                              )
                            ],
                          )),
                    ],
                  ))),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SingleChildScrollView(
            padding: EdgeInsets.only(top: 20),
            child: Center(
                child: Container(
                    width: 330,
                    decoration: BoxDecoration(
                      color: appColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: appColors.textSecondary,
                        width: 0.5,
                      ),
                    ),
                    child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name + Avatar row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(height: 10),
                                      Text("Name", style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
                                      CupertinoTextField(
                                        controller: _displayName,
                                        prefix: Icon(Icons.lock_outline_rounded, size: 15, color: appColors.textPrimary),
                                        style: TextStyle(color: appColors.textPrimary, fontSize: 18),
                                        placeholder: state.userModel?.displayName ?? '',
                                        placeholderStyle: TextStyle(color: appColors.textSecondary, fontSize: 18),
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      Container(height: 5),
                                      _divider(),
                                      Container(height: 20),
                                    ],
                                  ),
                                ),
                                Container(width: 15),
                                _buildAvatarEdit(state),
                              ],
                            ),
                            // Bio
                            _fieldSection(
                              label: "Bio",
                              controller: _bio,
                              placeholder: 'Add bio',
                            ),
                            // Link
                            _fieldSection(
                              label: "Link",
                              controller: _link,
                              placeholder: 'Add link',
                            ),
                            // Pronouns
                            _fieldSection(
                              label: "Pronouns",
                              controller: _pronouns,
                              placeholder: 'Add pronouns',
                            ),
                            // Location
                            _fieldSection(
                              label: "Location",
                              controller: _location,
                              placeholder: 'Add location',
                            ),
                            // Gender selector
                            _selectorSection(
                              label: "Gender",
                              value: _genderLabel(_selectedGender),
                              onTap: _showGenderPicker,
                            ),
                            // Account Type selector
                            _selectorSection(
                              label: "Account Type",
                              value: _accountTypeLabel(_accountType),
                              onTap: _showAccountTypePicker,
                            ),
                            // Private Account toggle
                            _toggleSection(
                              label: "Private Account",
                              value: _isPrivate,
                              onChanged: (val) {
                                setState(() { _isPrivate = val; });
                              },
                            ),
                            Container(height: 10),
                          ],
                        ))))));
  }

  Widget _divider() {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Container(width: 300, height: 0.5, color: appColors.textSecondary);
  }

  Widget _fieldSection({
    required String label,
    required TextEditingController controller,
    required String placeholder,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
        CupertinoTextField(
          controller: controller,
          prefix: Icon(Icons.add, size: 15, color: appColors.textPrimary),
          style: TextStyle(color: appColors.textPrimary, fontSize: 18),
          placeholder: placeholder,
          placeholderStyle: TextStyle(color: appColors.textSecondary, fontSize: 16),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        ),
        Container(height: 10),
        _divider(),
        Container(height: 20),
      ],
    );
  }

  Widget _selectorSection({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: appColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(value, style: TextStyle(color: appColors.textSecondary, fontSize: 14)),
              ),
            ],
          ),
        ),
        Container(height: 10),
        _divider(),
        Container(height: 20),
      ],
    );
  }

  Widget _toggleSection({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeColor: appColors.accent,
            ),
          ],
        ),
        Container(height: 10),
        _divider(),
        Container(height: 20),
      ],
    );
  }

  Widget _buildAvatarEdit(AuthState state) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return GestureDetector(
      onTap: () {
        showCupertinoModalPopup(
          context: context,
          builder: (BuildContext context) => CupertinoTheme(
            data: CupertinoThemeData(brightness: Theme.of(context).brightness),
            child: CupertinoActionSheet(
              title: Text('Change avatar'),
              message: Text('Your avatar is visible to everyone'),
              actions: <Widget>[
                CupertinoActionSheetAction(
                  child: Text('Gallery'),
                  onPressed: () {
                    getImage(context, ImageSource.gallery, (file) {
                      setState(() { _image = file; });
                    });
                    Navigator.pop(context);
                  },
                ),
                CupertinoActionSheetAction(
                  child: Text('Camera'),
                  onPressed: () {
                    getImage(context, ImageSource.camera, (file) {
                      setState(() { _image = file; });
                    });
                    Navigator.pop(context);
                  },
                ),
                CupertinoActionSheetAction(
                  child: Text('Remove', style: TextStyle(color: appColors.destructive)),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
              cancelButton: CupertinoActionSheetAction(
                child: Text('Cancel'),
                onPressed: () { Navigator.pop(context); },
              ),
            ),
          ),
        );
      },
      child: CircleAvatar(
        backgroundColor: appColors.surface,
        radius: 25,
        backgroundImage: (_image != null
            ? FileImage(_image!)
            : (state.profileUserModel?.profilePic ?? '').isEmpty
                ? null
                : CachedNetworkImageProvider(
                    scale: 2,
                    state.profileUserModel!.profilePic!,
                  ) as ImageProvider),
        child: (_image == null && (state.profileUserModel?.profilePic ?? '').isEmpty)
            ? Icon(Icons.person, size: 30, color: appColors.textSecondary)
            : null,
      ),
    );
  }

  void _showGenderPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoTheme(
        data: CupertinoThemeData(brightness: Theme.of(context).brightness),
        child: CupertinoActionSheet(
          title: Text('Gender'),
          actions: [
            CupertinoActionSheetAction(
              child: Text('Not set', style: _selectedGender == 1 ? TextStyle(fontWeight: FontWeight.bold) : null),
              onPressed: () { setState(() { _selectedGender = 1; }); Navigator.pop(context); },
            ),
            CupertinoActionSheetAction(
              child: Text('Male', style: _selectedGender == 2 ? TextStyle(fontWeight: FontWeight.bold) : null),
              onPressed: () { setState(() { _selectedGender = 2; }); Navigator.pop(context); },
            ),
            CupertinoActionSheetAction(
              child: Text('Female', style: _selectedGender == 3 ? TextStyle(fontWeight: FontWeight.bold) : null),
              onPressed: () { setState(() { _selectedGender = 3; }); Navigator.pop(context); },
            ),
            CupertinoActionSheetAction(
              child: Text('Other', style: _selectedGender == 4 ? TextStyle(fontWeight: FontWeight.bold) : null),
              onPressed: () { setState(() { _selectedGender = 4; }); Navigator.pop(context); },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: Text('Cancel'),
            onPressed: () { Navigator.pop(context); },
          ),
        ),
      ),
    );
  }

  void _showAccountTypePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoTheme(
        data: CupertinoThemeData(brightness: Theme.of(context).brightness),
        child: CupertinoActionSheet(
          title: Text('Account Type'),
          actions: [
            CupertinoActionSheetAction(
              child: Text('Personal', style: _accountType == 1 ? TextStyle(fontWeight: FontWeight.bold) : null),
              onPressed: () { setState(() { _accountType = 1; }); Navigator.pop(context); },
            ),
            CupertinoActionSheetAction(
              child: Text('Creator', style: _accountType == 2 ? TextStyle(fontWeight: FontWeight.bold) : null),
              onPressed: () { setState(() { _accountType = 2; }); Navigator.pop(context); },
            ),
            CupertinoActionSheetAction(
              child: Text('Business', style: _accountType == 3 ? TextStyle(fontWeight: FontWeight.bold) : null),
              onPressed: () { setState(() { _accountType = 3; }); Navigator.pop(context); },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: Text('Cancel'),
            onPressed: () { Navigator.pop(context); },
          ),
        ),
      ),
    );
  }

  Future<void> _submitButton() async {
    if (_displayName.text.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Max 100 characters'),
      ));
      return;
    }
    if (_bio.text.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Max 500 characters for bio'),
      ));
      return;
    }
    var state = Provider.of<AuthState>(context, listen: false);
    var model = state.userModel!.copyWith(
      displayName: _displayName.text,
      bio: _bio.text,
      link: _link.text,
      pronouns: _pronouns.text.isEmpty ? null : _pronouns.text,
      gender: _selectedGender,
      location: _location.text.isEmpty ? null : _location.text,
      isPrivate: _isPrivate,
      accountType: _accountType,
    );
    try {
      await state.updateUserProfile(model, image: _image);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Update failed, please retry'),
        ));
      }
    }
  }
}
