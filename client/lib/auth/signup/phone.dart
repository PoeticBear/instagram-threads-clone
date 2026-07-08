import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:threads/auth/username_setup_dialog.dart';
import 'package:threads/l10n/generated/app_localizations.dart';
import 'package:threads/pages/home.dart';
import 'package:threads/state/auth.state.dart';
import 'package:threads/theme/app_colors.dart';

/// 手机号 + 短信验证码登录页。
///
/// 服务端契约（openapi_docs/versions/openapi_20260708.json）：
///   - POST /auth/sms/send   {phone_country_code(2–10), phone(1–20)} → OKResponse
///   - POST /auth/sms/signin {phone_country_code, phone, code(4–6)} → SigninResponse
/// 区号与本地手机号分开采集；登录成功复用既有登录态落地（AuthState.signInWithSms），
/// 过 needsUsernameSetup 闸门后进主页，与其它登录方式一致。
class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({Key? key}) : super(key: key);

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String _countryCode = '+86';
  bool _isLoading = false;
  bool _sendingCode = false;

  // 倒计时剩余秒数，>0 时「获取验证码」按钮置灰
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _countdown -= 1;
        if (_countdown <= 0) t.cancel();
      });
    });
  }

  /// 区号校验：+ 开头、整体长度 2–10（与服务端 phone_country_code 约束一致）。
  bool _isValidCountryCode(String code) {
    return RegExp(r'^\+\d{1,9}$').hasMatch(code) &&
        code.length >= 2 &&
        code.length <= 10;
  }

  Future<void> _handleSendCode() async {
    if (_sendingCode || _countdown > 0) return;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterPhoneNumber)),
      );
      return;
    }
    if (!_isValidCountryCode(_countryCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.countryCodeInvalid)),
      );
      return;
    }

    setState(() => _sendingCode = true);
    try {
      final authState = Provider.of<AuthState>(context, listen: false);
      await authState.authService.sendSmsCode(
        phoneCountryCode: _countryCode,
        phone: phone,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.smsCodeSent)),
      );
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      // 业务失败（code != 0）由 ApiClient 抛 ServerException(msg)；
      // 不进倒计时，用户可立即修正重发。
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterPhoneNumber)),
      );
      return;
    }
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterVerificationCode)),
      );
      return;
    }

    setState(() => _isLoading = true);
    final authState = Provider.of<AuthState>(context, listen: false);
    final scaffoldKey = GlobalKey<ScaffoldState>();
    String? result;
    try {
      result = await authState.signInWithSms(
        _countryCode,
        phone,
        code,
        context,
        scaffoldKey: scaffoldKey,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;
    if (result != null) {
      // 与 NamePage 出口一致：username 为空先强制补填，再进首页
      if (authState.needsUsernameSetup) {
        await UsernameSetupDialog.show(context, authState);
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  Future<void> _openCountryCodePicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CountryCodePicker(initialCode: _countryCode),
    );
    if (selected != null && mounted) {
      setState(() => _countryCode = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        backgroundColor: appColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: appColors.textPrimary),
        title: Text(
          l.phoneLoginTitle,
          style: TextStyle(color: appColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.phoneLoginSubtitle,
                style: TextStyle(color: appColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              // 区号 + 手机号
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _openCountryCodePicker,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: appColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _countryCode,
                            style: TextStyle(
                              color: appColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: appColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: appColors.textPrimary),
                        decoration: _inputDecoration(l.phoneNumberHint, appColors),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 验证码 + 获取验证码
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: appColors.textPrimary),
                        decoration: _inputDecoration(l.verificationCodeHint, appColors),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_sendingCode || _countdown > 0) ? null : _handleSendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appColors.surface,
                        foregroundColor: appColors.textPrimary,
                        disabledBackgroundColor: appColors.surfaceSecondary,
                        disabledForegroundColor: appColors.textMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _sendingCode
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: appColors.textSecondary,
                              ),
                            )
                          : Text(
                              _countdown > 0 ? l.resendCountdown(_countdown) : l.sendCode,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors.textPrimary,
                    foregroundColor: appColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: appColors.background)
                      : Text(
                          l.loginButton,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, AppColors appColors) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: appColors.textHint),
      filled: true,
      fillColor: appColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }
}

/// 国家/地区区号数据。
class _CountryCode {
  final String flag;
  final String dialCode;
  final String nameEn;
  final String nameZh;
  const _CountryCode({
    required this.flag,
    required this.dialCode,
    required this.nameEn,
    required this.nameZh,
  });
}

// 常用国家/地区（区号不全会被「自定义区号」入口兜底）。
const List<_CountryCode> _kCountryCodes = [
  _CountryCode(flag: '🇨🇳', dialCode: '+86', nameEn: 'China', nameZh: '中国大陆'),
  _CountryCode(flag: '🇭🇰', dialCode: '+852', nameEn: 'Hong Kong', nameZh: '中国香港'),
  _CountryCode(flag: '🇲🇴', dialCode: '+853', nameEn: 'Macau', nameZh: '中国澳门'),
  _CountryCode(flag: '🇹🇼', dialCode: '+886', nameEn: 'Taiwan', nameZh: '中国台湾'),
  _CountryCode(flag: '🇺🇸', dialCode: '+1', nameEn: 'United States', nameZh: '美国'),
  _CountryCode(flag: '🇨🇦', dialCode: '+1', nameEn: 'Canada', nameZh: '加拿大'),
  _CountryCode(flag: '🇬🇧', dialCode: '+44', nameEn: 'United Kingdom', nameZh: '英国'),
  _CountryCode(flag: '🇯🇵', dialCode: '+81', nameEn: 'Japan', nameZh: '日本'),
  _CountryCode(flag: '🇰🇷', dialCode: '+82', nameEn: 'South Korea', nameZh: '韩国'),
  _CountryCode(flag: '🇸🇬', dialCode: '+65', nameEn: 'Singapore', nameZh: '新加坡'),
  _CountryCode(flag: '🇲🇾', dialCode: '+60', nameEn: 'Malaysia', nameZh: '马来西亚'),
  _CountryCode(flag: '🇦🇺', dialCode: '+61', nameEn: 'Australia', nameZh: '澳大利亚'),
  _CountryCode(flag: '🇳🇿', dialCode: '+64', nameEn: 'New Zealand', nameZh: '新西兰'),
  _CountryCode(flag: '🇹🇭', dialCode: '+66', nameEn: 'Thailand', nameZh: '泰国'),
  _CountryCode(flag: '🇻🇳', dialCode: '+84', nameEn: 'Vietnam', nameZh: '越南'),
  _CountryCode(flag: '🇮🇩', dialCode: '+62', nameEn: 'Indonesia', nameZh: '印度尼西亚'),
  _CountryCode(flag: '🇵🇭', dialCode: '+63', nameEn: 'Philippines', nameZh: '菲律宾'),
  _CountryCode(flag: '🇮🇳', dialCode: '+91', nameEn: 'India', nameZh: '印度'),
  _CountryCode(flag: '🇩🇪', dialCode: '+49', nameEn: 'Germany', nameZh: '德国'),
  _CountryCode(flag: '🇫🇷', dialCode: '+33', nameEn: 'France', nameZh: '法国'),
  _CountryCode(flag: '🇮🇹', dialCode: '+39', nameEn: 'Italy', nameZh: '意大利'),
  _CountryCode(flag: '🇪🇸', dialCode: '+34', nameEn: 'Spain', nameZh: '西班牙'),
  _CountryCode(flag: '🇳🇱', dialCode: '+31', nameEn: 'Netherlands', nameZh: '荷兰'),
  _CountryCode(flag: '🇷🇺', dialCode: '+7', nameEn: 'Russia', nameZh: '俄罗斯'),
  _CountryCode(flag: '🇧🇷', dialCode: '+55', nameEn: 'Brazil', nameZh: '巴西'),
  _CountryCode(flag: '🇲🇽', dialCode: '+52', nameEn: 'Mexico', nameZh: '墨西哥'),
  _CountryCode(flag: '🇦🇪', dialCode: '+971', nameEn: 'United Arab Emirates', nameZh: '阿联酋'),
  _CountryCode(flag: '🇸🇦', dialCode: '+966', nameEn: 'Saudi Arabia', nameZh: '沙特阿拉伯'),
  _CountryCode(flag: '🇹🇷', dialCode: '+90', nameEn: 'Turkey', nameZh: '土耳其'),
  _CountryCode(flag: '🇿🇦', dialCode: '+27', nameEn: 'South Africa', nameZh: '南非'),
];

/// 区号选择器：可搜索列表 + 自定义区号入口。pop 出选中的 dialCode（如 "+852"）。
class _CountryCodePicker extends StatefulWidget {
  final String initialCode;
  const _CountryCodePicker({required this.initialCode});

  @override
  State<_CountryCodePicker> createState() => _CountryCodePickerState();
}

class _CountryCodePickerState extends State<_CountryCodePicker> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _enterCustomCode() async {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    String? error;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(l.customCodeDialogTitle,
                style: TextStyle(color: appColors.textPrimary)),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: appColors.textPrimary),
              decoration: InputDecoration(
                hintText: l.customCodeHint,
                hintStyle: TextStyle(color: appColors.textHint),
                errorText: error,
                filled: true,
                fillColor: appColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: Text(l.cancel),
              ),
              TextButton(
                onPressed: () {
                  final v = controller.text.trim();
                  if (RegExp(r'^\+\d{1,9}$').hasMatch(v) &&
                      v.length >= 2 &&
                      v.length <= 10) {
                    Navigator.of(ctx).pop(v);
                  } else {
                    setState(() => error = l.countryCodeInvalid);
                  }
                },
                child: Text(l.confirmButton),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!.colors;
    final l = AppLocalizations.of(context)!;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final query = _query.toLowerCase().trim();

    final filtered = _kCountryCodes.where((c) {
      if (query.isEmpty) return true;
      final name = (isZh ? c.nameZh : c.nameEn).toLowerCase();
      return name.contains(query) || c.dialCode.contains(query);
    }).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.selectCountryCode,
                style: TextStyle(
                  color: appColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: appColors.textPrimary),
              decoration: InputDecoration(
                hintText: l.searchCountryCode,
                hintStyle: TextStyle(color: appColors.textHint),
                prefixIcon: Icon(Icons.search, color: appColors.textSecondary),
                filled: true,
                fillColor: appColors.surface,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: filtered.length + 1,
              itemBuilder: (ctx, i) {
                if (i == filtered.length) {
                  return ListTile(
                    leading: Icon(Icons.edit, color: appColors.textSecondary),
                    title: Text(l.customCountryCode,
                        style: TextStyle(color: appColors.textPrimary)),
                    onTap: _enterCustomCode,
                  );
                }
                final c = filtered[i];
                final selected = c.dialCode == widget.initialCode;
                return ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                  title: Text(isZh ? c.nameZh : c.nameEn,
                      style: TextStyle(color: appColors.textPrimary)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.dialCode,
                          style: TextStyle(
                              color: appColors.textSecondary, fontSize: 15)),
                      if (selected) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check, color: appColors.accent, size: 20),
                      ],
                    ],
                  ),
                  onTap: () => Navigator.of(context).pop(c.dialCode),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
