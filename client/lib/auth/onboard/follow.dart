import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:threads/auth/onboard/thread.dart';
import 'package:threads/theme/app_colors.dart';
import '../../widget/custom/rippleButton.dart';

class FollowerPage extends StatefulWidget {
  const FollowerPage({super.key});

  @override
  State<FollowerPage> createState() => _FollowerPageState();
}

class _FollowerPageState extends State<FollowerPage> {
  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      bottomNavigationBar: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
              padding: EdgeInsets.only(bottom: 30),
              child: RippleButton(
                  splashColor: Colors.transparent,
                  child: Container(
                      height: 50,
                      width: MediaQuery.of(context).size.width - 80,
                      decoration: BoxDecoration(
                        color: appColors.textPrimary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                          child: Text(
                        "Follow all",
                        style: TextStyle(
                            fontFamily: "icons.ttf",
                            color: appColors.background,
                            fontSize: 18,
                            fontWeight: FontWeight.w500),
                      ))),
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => ThreadPage()));
                  })),
        ],
      ),
      appBar: AppBar(
        backgroundColor: appColors.background,
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
            GestureDetector(
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => ThreadPage()));
                },
                child: Column(
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
                                Text("Next",
                                    style: TextStyle(
                                      color: appColors.textPrimary,
                                      fontSize: 20,
                                    )),
                                Padding(
                                    padding: EdgeInsets.only(left: 42),
                                    child:
                                        Icon(Icons.arrow_forward_ios_rounded))
                              ],
                            )),
                      ],
                    )
                  ],
                )),
          ],
        ),
      ),
      backgroundColor: appColors.background,
      body: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
        Container(
          height: 10,
        ),
        Text(
          "Follow the same accounts you\nfollow on Instagram?",
          style: TextStyle(
              color: appColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        Container(
          height: 20,
        ),
        Text(
          "How it works",
          style: TextStyle(
              color: appColors.textHint,
              fontSize: 16,
              fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        Container(
          height: 15,
        ),
        Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: CupertinoTextField(
              prefix: Row(
                children: [
                  Container(
                    width: 10,
                  ),
                  Icon(
                    Icons.search,
                    color: appColors.textSecondary,
                  )
                ],
              ),
              style: TextStyle(color: appColors.textPrimary, fontSize: 18),
              placeholder: 'Search',
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: appColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
            )),
        Expanded(
            child: ListView(
          children: [
            Container(
              height: 10,
            ),
            Container(
              height: 50,
              width: MediaQuery.of(context).size.width - 40,
              color: appColors.background,
              child: Row(
                children: [
                  Image.asset("assets/pp.jpg"),
                  Container(
                    width: 10,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Test_account",
                        style: TextStyle(
                            color: appColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        "testaccount123",
                        style: TextStyle(color: appColors.textSecondary),
                      ),
                    ],
                  ),
                  Container(
                    width: 120,
                  ),
                  GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ThreadPage()));
                      },
                      child: Container(
                          height: 30,
                          width: 90,
                          alignment: Alignment.center,
                          child: Text(
                            "Follow all",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          decoration: BoxDecoration(
                            color: appColors.background,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: appColors.border,
                              width: 0.5,
                            ),
                          )))
                ],
              ),
            )
          ],
        ))
      ]),
    );
  }
}
