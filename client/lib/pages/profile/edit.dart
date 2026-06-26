import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/helper/network_error.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/theme/app_colors.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _userName;
  late TextEditingController _displayName;
  late TextEditingController _bio;
  late TextEditingController _link;
  late TextEditingController _pronouns;
  late TextEditingController _location;
  File? _image;
  bool _avatarRemoved = false;
  bool _isSubmitting = false;
  int _selectedGender = 1; // 1=Not set, 2=Male, 3=Female, 4=Other
  bool _isPrivate = false;
  int _accountType = 1; // 1=Personal, 2=Creator, 3=Business

  @override
  void initState() {
    super.initState();
    final state = Provider.of<AuthState>(context, listen: false);
    _userName = TextEditingController(text: state.userModel?.userName ?? '');
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
    _userName.dispose();
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

  String _genderLabel(int value, AppLocalizations l10n) {
    switch (value) {
      case 2: return l10n.male;
      case 3: return l10n.female;
      case 4: return l10n.otherGender;
      default: return l10n.notSet;
    }
  }

  String _accountTypeLabel(int value, AppLocalizations l10n) {
    switch (value) {
      case 2: return l10n.creator;
      case 3: return l10n.business;
      default: return l10n.personal;
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
                                      child: Text(AppLocalizations.of(context)!.cancel,
                                          style: TextStyle(
                                              color: appColors.textPrimary,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w400)))),
                              Text(
                                AppLocalizations.of(context)!.editProfile,
                                style: TextStyle(
                                    color: appColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700),
                              ),
                              Padding(
                                padding: EdgeInsets.only(right: 15),
                                child: GestureDetector(
                                    onTap: _isSubmitting ? null : _submitButton,
                                    child: _isSubmitting
                                        ? CupertinoActivityIndicator()
                                        : Text(AppLocalizations.of(context)!.done,
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
                            // Username (@handle) —— 唯一身份标识，设定后不可修改
                            _fieldSection(
                              label: AppLocalizations.of(context)!.username,
                              controller: _userName,
                              placeholder: AppLocalizations.of(context)!.usernameHint,
                              leadingIcon: Icons.alternate_email,
                              readOnly: true,
                            ),
                            // Name + Avatar row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(height: 10),
                                      Text(AppLocalizations.of(context)!.name, style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
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
                              label: AppLocalizations.of(context)!.bio,
                              controller: _bio,
                              placeholder: AppLocalizations.of(context)!.addBio,
                            ),
                            // Link
                            _fieldSection(
                              label: AppLocalizations.of(context)!.linkLabel,
                              controller: _link,
                              placeholder: AppLocalizations.of(context)!.addLinkField,
                            ),
                            // Pronouns
                            _fieldSection(
                              label: AppLocalizations.of(context)!.pronouns,
                              controller: _pronouns,
                              placeholder: AppLocalizations.of(context)!.addPronouns,
                            ),
                            // Location
                            _fieldSection(
                              label: AppLocalizations.of(context)!.locationLabel,
                              controller: _location,
                              placeholder: AppLocalizations.of(context)!.addLocationField,
                            ),
                            // Gender selector
                            _selectorSection(
                              label: AppLocalizations.of(context)!.gender,
                              value: _genderLabel(_selectedGender, AppLocalizations.of(context)!),
                              onTap: _showGenderPicker,
                            ),
                            // Account Type selector
                            _selectorSection(
                              label: AppLocalizations.of(context)!.accountType,
                              value: _accountTypeLabel(_accountType, AppLocalizations.of(context)!),
                              onTap: _showAccountTypePicker,
                            ),
                            // Private Account toggle
                            _toggleSection(
                              label: AppLocalizations.of(context)!.privateAccount,
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
    IconData? leadingIcon,
    bool readOnly = false,
  }) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
            if (readOnly) ...[
              const SizedBox(width: 6),
              Icon(Icons.lock_outline, size: 14, color: appColors.textSecondary),
            ],
          ],
        ),
        CupertinoTextField(
          controller: controller,
          readOnly: readOnly,
          prefix: Icon(leadingIcon ?? Icons.add, size: 15, color: appColors.textPrimary),
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
              title: Text(AppLocalizations.of(context)!.changeAvatar),
              message: Text(AppLocalizations.of(context)!.avatarVisibility),
              actions: <Widget>[
                CupertinoActionSheetAction(
                  child: Text(AppLocalizations.of(context)!.gallery),
                  onPressed: () {
                    getImage(context, ImageSource.gallery, (file) {
                      setState(() { _image = file; _avatarRemoved = false; });
                    });
                    Navigator.pop(context);
                  },
                ),
                CupertinoActionSheetAction(
                  child: Text(AppLocalizations.of(context)!.cameraLabel),
                  onPressed: () {
                    getImage(context, ImageSource.camera, (file) {
                      setState(() { _image = file; _avatarRemoved = false; });
                    });
                    Navigator.pop(context);
                  },
                ),
                CupertinoActionSheetAction(
                  child: Text(AppLocalizations.of(context)!.remove, style: TextStyle(color: appColors.destructive)),
                  onPressed: () {
                    setState(() { _image = null; _avatarRemoved = true; });
                    Navigator.pop(context);
                  },
                ),
              ],
              cancelButton: CupertinoActionSheetAction(
                child: Text(AppLocalizations.of(context)!.cancel),
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
            : (!_avatarRemoved && (state.profileUserModel?.profilePic ?? '').isNotEmpty)
                ? CachedNetworkImageProvider(
                    scale: 2,
                    state.profileUserModel!.profilePic!,
                  ) as ImageProvider
                : null),
        child: (_image == null && (_avatarRemoved || (state.profileUserModel?.profilePic ?? '').isEmpty))
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
          title: Text(AppLocalizations.of(context)!.gender),
          actions: [
            CupertinoActionSheetAction(
              child: Text(AppLocalizations.of(context)!.notSet, style: _selectedGender == 1 ? TextStyle(fontWeight: FontWeight.bold) : null),
              onPressed: () { setState(() { _selectedGender = 1; }); Navigator.pop(context); },
            ),
            CupertinoActionSheetAction(
              child: Text(AppLocalizations.of(context)!.male, style: _selectedGender == 2 ? TextStyle(fontWeight: FontWeight.bold) : null),
              onPressed: () { setState(() { _selectedGender = 2; }); Navigator.pop(context); },
            ),
            CupertinoActionSheetAction(
              child: Text(AppLocalizations.of(context)!.female, style: _selectedGender == 3 ? TextStyle(fontWeight: FontWeight.bold) : null),
              onPressed: () { setState(() { _selectedGender = 3; }); Navigator.pop(context); },
            ),
            CupertinoActionSheetAction(
              child: Text(AppLocalizations.of(context)!.otherGender, style: _selectedGender == 4 ? TextStyle(fontWeight: FontWeight.bold) : null),
              onPressed: () { setState(() { _selectedGender = 4; }); Navigator.pop(context); },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: Text(AppLocalizations.of(context)!.cancel),
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
          title: Text(AppLocalizations.of(context)!.accountType),
          actions: [
            CupertinoActionSheetAction(
              child: Text(AppLocalizations.of(context)!.personal, style: _accountType == 1 ? TextStyle(fontWeight: FontWeight.bold) : null),
              onPressed: () { setState(() { _accountType = 1; }); Navigator.pop(context); },
            ),
            CupertinoActionSheetAction(
              child: Text(AppLocalizations.of(context)!.creator, style: _accountType == 2 ? TextStyle(fontWeight: FontWeight.bold) : null),
              onPressed: () { setState(() { _accountType = 2; }); Navigator.pop(context); },
            ),
            CupertinoActionSheetAction(
              child: Text(AppLocalizations.of(context)!.business, style: _accountType == 3 ? TextStyle(fontWeight: FontWeight.bold) : null),
              onPressed: () { setState(() { _accountType = 3; }); Navigator.pop(context); },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: Text(AppLocalizations.of(context)!.cancel),
            onPressed: () { Navigator.pop(context); },
          ),
        ),
      ),
    );
  }

  Future<void> _submitButton() async {
    if (_isSubmitting) return;
    if (_displayName.text.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.maxNameChars),
      ));
      return;
    }
    if (_bio.text.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.maxBioChars),
      ));
      return;
    }
    setState(() { _isSubmitting = true; });
    var state = Provider.of<AuthState>(context, listen: false);
    var model = state.userModel!.copyWith(
      userName: _userName.text,
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
      await state.updateUserProfile(model, image: _image, removeAvatar: _avatarRemoved);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        NetworkErrorNotifier.showApiError(e);
      }
    } finally {
      if (mounted) setState(() { _isSubmitting = false; });
    }
  }
}
