import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/theme/app_colors.dart';

class SwitchAccount extends StatefulWidget {
  const SwitchAccount({super.key});

  @override
  State<SwitchAccount> createState() => _SwitchAccountState();
}

class _SwitchAccountState extends State<SwitchAccount> {
  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
        appBar: AppBar(
          leading: Container(),
          flexibleSpace: Column(
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
                            padding: EdgeInsets.only(left: 35, top: 10),
                            child: Text("Back",
                                style: TextStyle(
                                  color: appColors.textPrimary,
                                  fontSize: 23,
                                ))),
                      )
                    ],
                  ),
                ],
              )
            ],
          ),
          backgroundColor: appColors.background,
        ),
        backgroundColor: appColors.background,
        body: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                Text(
                  "Switch accounts",
                  style: TextStyle(
                      color: appColors.textPrimary,
                      fontSize: 25,
                      fontWeight: FontWeight.w700),
                ),
                Container(
                  height: 20,
                ),
                Text(
                  "If you don't see the account you're looking\nfor here, you'll need to sign in on Instagram\nfirst.",
                  style: TextStyle(
                      color: appColors.textHint,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                Container(
                  height: 100,
                ),
                GestureDetector(
                    onTap: () {
                      Platform.isIOS
                          ? showDialog(
                              context: context,
                              builder: (_) => CupertinoAlertDialog(
                                    title: const Text("Account"),
                                    content: const Text(
                                        "There is no more account in this test application, create it"),
                                    actions: [
                                      CupertinoDialogAction(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: Text(
                                          'Confirm',
                                          style: TextStyle(color: appColors.accent),
                                        ),
                                      ),
                                    ],
                                  ))
                          : showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                    contentPadding: EdgeInsets.only(
                                        right: 50,
                                        left: 50,
                                        top: 20,
                                        bottom: 20),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(40))),
                                    backgroundColor: appColors.background,
                                    title: Text(
                                      "Account",
                                      style: TextStyle(
                                          color: appColors.textPrimary,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    content: Text(
                                      'There is no more account in this test application, create it',
                                      style: TextStyle(
                                          color: appColors.textSecondary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w100),
                                    ),
                                    actions: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          GestureDetector(
                                              onTap: () {
                                                Navigator.pop(context);
                                              },
                                              child: Text("Ok",
                                                  style: TextStyle(
                                                      color: appColors.accent,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 14))),
                                        ],
                                      )
                                    ],
                                  ));
                    },
                    child: Container(
                        height: 175,
                        width: 330,
                        decoration: BoxDecoration(
                          color: appColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: appColors.border,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  width: 30,
                                ),
                                Image.asset(
                                  "assets/pp.jpg",
                                  height: 60,
                                ),
                                Container(
                                  width: 10,
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Test_account",
                                      style: TextStyle(
                                          color: appColors.textPrimary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      "testaccount123",
                                      style: TextStyle(color: appColors.textSecondary),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 80,
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: appColors.textPrimary,
                                )
                              ],
                            ),
                            Padding(
                                padding: EdgeInsets.symmetric(vertical: 15),
                                child: Container(
                                  width: 300,
                                  height: 0.5,
                                  color: appColors.divider,
                                )),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  width: 20,
                                ),
                                Image.asset(
                                  "assets/pp.jpg",
                                  height: 60,
                                ),
                                Container(
                                  width: 10,
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Test_account2",
                                      style: TextStyle(
                                          color: appColors.textPrimary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      "testaccount21",
                                      style: TextStyle(color: appColors.textSecondary),
                                    )
                                  ],
                                ),
                                Container(
                                  width: 70,
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: appColors.textPrimary,
                                )
                              ],
                            ),
                          ],
                        ))),
                Container(
                  height: MediaQuery.of(context).size.height / 4,
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    "Log in to another Instagram account",
                    style: TextStyle(
                        color: appColors.textHint,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                )
              ],
            ),
          ],
        ));
  }
}
