// ignore_for_file: avoid_print, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:threads/l10n/generated/app_localizations.dart';

class Utility {
  static String getUserName({
    required String id,
    required String name,
  }) {
    String userName = '';
    if (name.length > 15) {
      name = name.substring(0, 6);
    }
    name = name.split(' ')[0];
    id = id.substring(0, 4).toLowerCase();
    userName = '@$name$id';
    return userName;
  }

  static String getdob(String? date, {BuildContext? context}) {
    if (date == null || date.isEmpty) {
      return '';
    }
    var dt = DateTime.parse(date).toLocal();
    final now = DateTime.now();
    final difference = now.difference(dt);

    final l10n = context != null ? AppLocalizations.of(context) : null;

    if (l10n == null) {
      return DateFormat.yMMMd().format(dt);
    }

    if (difference.inMinutes < 1) {
      return l10n.justNow;
    } else if (difference.inMinutes < 60) {
      return l10n.minutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l10n.hoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return l10n.daysAgo(difference.inDays);
    } else {
      final locale = Localizations.localeOf(context!).toString();
      return DateFormat.yMMMd(locale).format(dt);
    }
  }

  static bool validateCredentials(BuildContext context,
      GlobalKey<ScaffoldState> _scaffoldKey, String? email, String? password) {
    if (email == null || email.isEmpty) {
      customSnackBar(_scaffoldKey, 'Please enter email id', context);
      return false;
    } else if (password == null || password.isEmpty) {
      customSnackBar(_scaffoldKey, 'Please enter password', context);
      return false;
    } else if (password.length < 8) {
      customSnackBar(
          _scaffoldKey, 'Password must me 8 character long', context);
      return false;
    }

    var status = validateEmal(email);
    if (!status) {
      customSnackBar(_scaffoldKey, 'Please enter valid email id', context);
      return false;
    }
    return true;
  }

  static customSnackBar(
      GlobalKey<ScaffoldState>? _scaffoldKey, String msg, BuildContext context,
      {double height = 30, Color backgroundColor = Colors.black}) {
    if (_scaffoldKey == null || _scaffoldKey.currentState == null) {
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final snackBar = SnackBar(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      content: Text(
        msg,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color.fromARGB(255, 0, 0, 0),
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static bool validateEmal(String email) {
    String p =
        r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';

    RegExp regExp = RegExp(p);

    var status = regExp.hasMatch(email);
    return status;
  }
}