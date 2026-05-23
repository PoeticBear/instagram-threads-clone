import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:threads/state/auth.state.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _displayName;
  late TextEditingController _bio;
  late TextEditingController _link;
  File? _image;

  @override
  void initState() {
    super.initState();
    final state = Provider.of<AuthState>(context, listen: false);
    // Debug: check if userModel is loaded
    debugPrint('EditProfilePage initState - userModel: ${state.userModel?.displayName}');
    _displayName = TextEditingController(text: state.userModel?.displayName ?? '');
    _bio = TextEditingController(text: state.userModel?.bio ?? '');
    _link = TextEditingController(text: state.userModel?.link ?? '');
    debugPrint('TextFields initialized with: displayName="${_displayName.text}", bio="${_bio.text}", link="${_link.text}"');
  }

  @override
  void dispose() {
    _bio.dispose();
    _link.dispose();
    _displayName.dispose();
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

  @override
  Widget build(BuildContext context) {
    var state = Provider.of<AuthState>(context);
    return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          toolbarHeight: 68,
          leading: Container(),
          flexibleSpace: Padding(
              padding: EdgeInsets.only(left: 5, top: 60),
              child: Container(
                  decoration: BoxDecoration(
                      color: Color.fromARGB(255, 29, 29, 29),
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
                                      child: Text("取消",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w400)))),
                              Text(
                                "编辑资料   ",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700),
                              ),
                              Padding(
                                padding: EdgeInsets.only(right: 15),
                                child: GestureDetector(
                                    onTap: _submitButton,
                                    child: Text("完成",
                                        style: TextStyle(
                                            color: Colors.blue,
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
        body: Padding(
            padding: EdgeInsets.only(top: 100),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    width: 330,
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, 25, 25, 25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey,
                        width: 0.5,
                      ),
                    ),
                    child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 200,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 10,
                                      ),
                                      Text(
                                        "名称",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 18),
                                      ),
                                      CupertinoTextField(
                                        controller: _displayName,
                                        prefix: Icon(
                                          Icons.lock_outline_rounded,
                                          size: 15,
                                          color: Colors.white,
                                        ),
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 18),
                                        placeholder:
                                            state.userModel!.displayName,
                                        placeholderStyle: TextStyle(
                                            color: Colors.grey, fontSize: 18),
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      Container(
                                        height: 5,
                                      ),
                                      Container(
                                        width: 300,
                                        height: 0.5,
                                        color: Colors.grey,
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
                                        builder: (BuildContext context) =>
                                            CupertinoTheme(
                                              data: CupertinoThemeData(
                                                brightness: Brightness
                                                    .dark, // Définir le mode sombre
                                              ),
                                              child: CupertinoActionSheet(
                                                title: Text(
                                                    '更换头像'),
                                                message: Text(
                                                    '你的头像对所有人可见，方便好友更容易找到你'),
                                                actions: <Widget>[
                                                  CupertinoActionSheetAction(
                                                    child: Text('相册'),
                                                    onPressed: () {
                                                      getImage(context,
                                                          ImageSource.gallery,
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
                                                    child:
                                                        Text('拍照'),
                                                    onPressed: () {
                                                      getImage(context,
                                                          ImageSource.camera,
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
                                                      '删除头像',
                                                      style: TextStyle(
                                                          color: Colors.red),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                    },
                                                  ),
                                                ],
                                                cancelButton:
                                                    CupertinoActionSheetAction(
                                                  child: Text('取消'),
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                  },
                                                ),
                                              ),
                                            ));
                                  },
                                  child: CircleAvatar(
                                      backgroundColor: Colors.grey[800],
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
                                          ? Icon(Icons.person, size: 30, color: Colors.grey[600])
                                          : null),
                                )
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "简介",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18),
                                ),
                                CupertinoTextField(
                                  controller: _bio,
                                  prefix: Icon(
                                    Icons.add,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 18),
                                  placeholder: '填写简介',
                                  placeholderStyle: TextStyle(
                                      color: Colors.grey, fontSize: 16),
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
                                  color: Colors.grey,
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
                                  "链接",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18),
                                ),
                                CupertinoTextField(
                                  controller: _link,
                                  prefix: Icon(
                                    Icons.add,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 18),
                                  placeholder: '添加链接',
                                  placeholderStyle: TextStyle(
                                      color: Colors.grey, fontSize: 16),
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ))),
              ],
            )));
  }

  Future<void> _submitButton() async {
    if (_displayName.text.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40), topRight: Radius.circular(40))),
        backgroundColor: Colors.white,
        content: Container(
            alignment: Alignment.center,
            height: 30,
            child: Text(
              '最多100个字符',
              style: TextStyle(
                  fontFamily: "icons.ttf",
                  color: Colors.black,
                  fontSize: 25,
                  fontWeight: FontWeight.w900),
            )),
      ));
      return;
    }
    if (_bio.text.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40), topRight: Radius.circular(40))),
        backgroundColor: Colors.white,
        content: Container(
            alignment: Alignment.center,
            height: 30,
            child: Text(
              '最多100个字符',
              style: TextStyle(
                  fontFamily: "icons.ttf",
                  color: Colors.black,
                  fontSize: 25,
                  fontWeight: FontWeight.w900),
            )),
      ));
      return;
    }
    var state = Provider.of<AuthState>(context, listen: false);
    var model = state.userModel!.copyWith(
      displayName: _displayName.text,
      bio: _bio.text,
      link: _link.text,
    );
    try {
      await state.updateUserProfile(model, image: _image);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('更新失败，请重试'),
        ));
      }
    }
  }
}
