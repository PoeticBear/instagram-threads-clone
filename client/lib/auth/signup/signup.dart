import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:threads/auth/signup/email.dart';
import 'package:threads/theme/app_colors.dart';

class Signup extends StatefulWidget {
  const Signup({Key? key}) : super(key: key);
  @override
  State<StatefulWidget> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _linkController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _linkController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  File? _image;

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

  Widget _body(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Column(mainAxisAlignment: MainAxisAlignment.start, children: [
      Container(
        height: 120,
      ),
      Text(
        "Profile",
        style: TextStyle(
            color: appColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
      Container(
        height: 20,
      ),
      Text(
        "Customize your Threads profile.",
        style: TextStyle(
            color: appColors.textHint,
            fontSize: 16,
            fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
      Container(
        height: 100,
      ),
      Container(
          height: 250,
          width: 330,
          decoration: BoxDecoration(
            color: appColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: appColors.border,
              width: 0.5,
            ),
          ),
          child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 200,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 10,
                            ),
                            Text(
                              "Name",
                              style: TextStyle(
                                  color: appColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18),
                            ),
                            CupertinoTextField(
                              controller: _nameController,
                              prefix: Icon(
                                Icons.lock_outline_rounded,
                                size: 15,
                                color: appColors.textPrimary,
                              ),
                              style:
                                  TextStyle(color: appColors.textPrimary, fontSize: 18),
                              placeholder: 'instagram account',
                              placeholderStyle:
                                  TextStyle(color: appColors.textSecondary, fontSize: 18),
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            Container(
                              height: 5,
                            ),
                            Container(
                              width: 300,
                              height: 0.5,
                              color: appColors.divider,
                            ),
                            Container(
                              height: 20,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 30,
                      ),
                      GestureDetector(
                        onTap: () {
                          showCupertinoModalPopup(
                              context: context,
                              builder: (BuildContext context) => CupertinoTheme(
                                    data: CupertinoThemeData(
                                      brightness: Theme.of(context).brightness,
                                    ),
                                    child: CupertinoActionSheet(
                                      title: Text('Changer de photo de profil'),
                                      message: Text(
                                          'Ta photo de profil est visible par tous et permetttra à tes amis de t\'ajoyter plus facilement'),
                                      actions: <Widget>[
                                        CupertinoActionSheetAction(
                                          child: Text('Photothèque'),
                                          onPressed: () {
                                            getImage(
                                                context, ImageSource.gallery,
                                                (file) {
                                              setState(() {
                                                _image = file;
                                              });
                                            });
                                            setState(() {});
                                            Navigator.pop(context);
                                          },
                                        ),
                                        CupertinoActionSheetAction(
                                          child: Text('Appareil photo'),
                                          onPressed: () {
                                            getImage(
                                                context, ImageSource.camera,
                                                (file) {
                                              setState(() {
                                                _image = file;
                                              });
                                            });
                                            Navigator.pop(context);
                                          },
                                        ),
                                        CupertinoActionSheetAction(
                                          child: Text(
                                            'Supprimer la photo de profil',
                                            style: TextStyle(color: appColors.destructive),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                        ),
                                      ],
                                      cancelButton: CupertinoActionSheetAction(
                                        child: Text('Annuler'),
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                      ),
                                    ),
                                  ));
                        },
                        child: CircleAvatar(
                            backgroundColor: Colors.transparent,
                            radius: 25,
                            backgroundImage: (_image != null
                                ? FileImage(_image!)
                                : CachedNetworkImageProvider(
                                    scale: 10,
                                    "https://static.vecteezy.com/system/resources/previews/005/544/718/original/profile-icon-design-free-vector.jpg",
                                  ) as ImageProvider)),
                      )
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bio",
                        style: TextStyle(
                            color: appColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 18),
                      ),
                      CupertinoTextField(
                        controller: _bioController,
                        prefix: Icon(
                          Icons.add,
                          size: 15,
                          color: appColors.textPrimary,
                        ),
                        style: TextStyle(color: appColors.textPrimary, fontSize: 18),
                        placeholder: 'Write bio',
                        placeholderStyle:
                            TextStyle(color: appColors.textSecondary, fontSize: 16),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      Container(
                        height: 10,
                      ),
                      Container(
                        width: 300,
                        height: 0.5,
                        color: appColors.divider,
                      ),
                      Container(
                        height: 20,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Link",
                        style: TextStyle(
                            color: appColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 18),
                      ),
                      CupertinoTextField(
                        controller: _linkController,
                        prefix: Icon(
                          Icons.add,
                          size: 15,
                          color: appColors.textPrimary,
                        ),
                        style: TextStyle(color: appColors.textPrimary, fontSize: 18),
                        placeholder: 'Add Link',
                        placeholderStyle:
                            TextStyle(color: appColors.textSecondary, fontSize: 16),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ))),
      Container(
        height: 20,
      ),
      GestureDetector(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => EmailPage(
                          name: _nameController.text,
                          bio: _bioController.text,
                          link: _linkController.text,
                          image: _image,
                        )));
          },
          child: Container(
            height: 50,
            width: MediaQuery.of(context).size.width - 80,
            decoration: BoxDecoration(
                color: appColors.textPrimary, borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.square_arrow_down,
                  color: appColors.background,
                ),
                Text(
                  " Import from Instagram",
                  style: TextStyle(color: appColors.background, fontSize: 16),
                )
              ],
            ),
          ))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      extendBodyBehindAppBar: true,
      key: _scaffoldKey,
      backgroundColor: appColors.background,
      appBar: AppBar(
        leading: Container(),
        flexibleSpace: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Container(
                  height: 50,
                ),
                Row(
                  children: [
                    Stack(
                      children: [
                        BackButton(),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Padding(
                              padding: EdgeInsets.only(left: 35, top: 12),
                              child: Text("Back",
                                  style: TextStyle(
                                    color: appColors.textPrimary,
                                    fontSize: 20,
                                  ))),
                        )
                      ],
                    ),
                  ],
                )
              ],
            ),
            Column(
              children: [
                Container(
                  height: 50,
                ),
                Row(
                  children: [
                    Padding(
                        padding: EdgeInsets.only(right: 10, top: 12),
                        child: Stack(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => EmailPage()));
                              },
                              child: Text("Skip",
                                  style: TextStyle(
                                    color: appColors.textPrimary,
                                    fontSize: 20,
                                  )),
                            ),
                            Padding(
                                padding: EdgeInsets.only(left: 42),
                                child: Icon(Icons.arrow_forward_ios_rounded))
                          ],
                        )),
                  ],
                )
              ],
            ),
          ],
        ),
        backgroundColor: appColors.background,
      ),
      body: SingleChildScrollView(child: _body(context)),
    );
  }
}
