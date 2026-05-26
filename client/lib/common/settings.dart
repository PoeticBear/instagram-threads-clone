import 'package:animate_do/animate_do.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/state/locale.state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    var state = Provider.of<AuthState>(context);
    return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.black,
        appBar: AppBar(
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
                                    child: Text(AppLocalizations.of(context)!.back,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                        ))),
                              )
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ]),
            leading: Container(),
            elevation: 0,
            backgroundColor: Colors.transparent,
            title: Padding(
                padding: EdgeInsets.only(bottom: 27),
                child: FadeInRight(
                    duration: Duration(milliseconds: 300),
                    child: Text(
                      AppLocalizations.of(context)!.settingsTitle,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 18),
                    )))),
        body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 0),
            child: ListView(
              children: [
                Container(
                  height: 0.5,
                  color: Color.fromARGB(255, 77, 77, 77),
                  width: MediaQuery.of(context).size.width,
                ),
                Container(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                    ),
                    Icon(
                      CupertinoIcons.person_add,
                      size: 30,
                    ),
                    Container(
                      width: 20,
                    ),
                    Text(
                      AppLocalizations.of(context)!.followAndInviteFriends,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    )
                  ],
                ),
                Container(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                    ),
                    Icon(
                      CupertinoIcons.bell,
                      size: 30,
                    ),
                    Container(
                      width: 20,
                    ),
                    Text(
                      AppLocalizations.of(context)!.notifications,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    )
                  ],
                ),
                Container(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                    ),
                    Icon(
                      Icons.lock_outline,
                      size: 30,
                    ),
                    Container(
                      width: 20,
                    ),
                    Text(
                      AppLocalizations.of(context)!.privacy,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    )
                  ],
                ),
                Container(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                    ),
                    Icon(
                      Icons.help_outline,
                      size: 30,
                    ),
                    Container(
                      width: 20,
                    ),
                    Text(
                      AppLocalizations.of(context)!.help,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    )
                  ],
                ),
                Container(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                    ),
                    Icon(
                      CupertinoIcons.info,
                      size: 30,
                    ),
                    Container(
                      width: 20,
                    ),
                    Text(
                      AppLocalizations.of(context)!.about,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    )
                  ],
                ),
                Container(
                  height: 15,
                ),
                Container(
                  height: 0.5,
                  color: Color.fromARGB(255, 77, 77, 77),
                  width: MediaQuery.of(context).size.width,
                ),
                Container(
                  height: 5,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                    ),
                    Icon(
                      CupertinoIcons.globe,
                      size: 30,
                    ),
                    Container(
                      width: 20,
                    ),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.language,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                    Consumer<LocaleProvider>(
                      builder: (context, localeProvider, _) {
                        return GestureDetector(
                          onTap: () {
                            final newLocale = localeProvider.locale.languageCode == 'en'
                                ? const Locale('zh')
                                : const Locale('en');
                            localeProvider.setLocale(newLocale);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xff1a1a1a),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              localeProvider.locale.languageCode == 'en' ? 'English' : '中文',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      width: 20,
                    ),
                  ],
                ),
                Container(
                  height: 15,
                ),
                Container(
                  height: 0.5,
                  color: Color.fromARGB(255, 77, 77, 77),
                  width: MediaQuery.of(context).size.width,
                ),
                Container(
                  height: 5,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                    ),
                    GestureDetector(
                        onTap: () {
                          state.logoutCallback();
                          Navigator.pop(context);
                        },
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 50,
                              alignment: Alignment.center,
                              child: Text(
                                AppLocalizations.of(context)!.logOut,
                                style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 17),
                              ),
                            ))),
                  ],
                ),
              ],
            )));
  }
}
