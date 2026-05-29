import 'package:flutter/material.dart';
import 'package:threads/auth/onboard/follow.dart';
import 'package:threads/theme/app_colors.dart';
import '../../widget/custom/rippleButton.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool isselected = false;
  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    return Scaffold(
      appBar: AppBar(
          backgroundColor: appColors.background,
          leading: Container(),
          flexibleSpace:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
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
            )
          ])),
      backgroundColor: appColors.background,
      body: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
        Container(
          height: 10,
        ),
        Text(
          "Privacy",
          style: TextStyle(
              color: appColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        Container(
          height: 20,
        ),
        Text(
          "You're privacy on Threads and Instagram\ncan be different. Learn more.",
          style: TextStyle(
              color: appColors.textHint,
              fontSize: 16,
              fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        Container(
          height: 90,
        ),
        GestureDetector(
            onTap: () {
              setState(() {
                isselected = false;
              });
            },
            child: Container(
              height: 120,
              width: 330,
              decoration: BoxDecoration(
                color: appColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: !isselected ? appColors.textPrimary : appColors.border,
                  width: !isselected ? 2 : 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "   Public profile",
                    style: TextStyle(
                        color: appColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "\n   Anyone on or off Threads can see,\n   share and interact with your content.",
                    style: TextStyle(
                        color: appColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )),
        Container(
          height: 20,
        ),
        GestureDetector(
            onTap: () {
              setState(() {
                isselected = true;
              });
            },
            child: Container(
              height: 120,
              width: 330,
              decoration: BoxDecoration(
                color: appColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isselected ? appColors.textPrimary : appColors.border,
                  width: isselected ? 2 : 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        "   Private profile",
                        style: TextStyle(
                            color: appColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                      Container(
                        width: 170,
                      ),
                      Icon(
                        Icons.lock_outlined,
                        color: appColors.textPrimary,
                      )
                    ],
                  ),
                  Text(
                    "\n   Only you aproved followers can\n   see and interact with your content.",
                    style: TextStyle(
                        color: appColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )),
        Container(
          height: MediaQuery.of(context).size.height / 7,
        ),
        RippleButton(
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
                  "Next",
                  style: TextStyle(
                      fontFamily: "icons.ttf",
                      color: appColors.background,
                      fontSize: 18,
                      fontWeight: FontWeight.w500),
                ))),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => FollowerPage()));
            }),
      ]),
    );
  }
}
