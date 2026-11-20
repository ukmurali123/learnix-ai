import 'package:flutter/material.dart';

/// The few live Learnix brand values the welcome page uses (copied from thinkzonGo's BrandConfig).
class BrandConfig {
  BrandConfig._();
  static const String appName = 'Learnix';
  static const String companyNameLower = 'OTOMATIKS';
  static const String logoAsset = 'assets/learnix_logo.png';
  static const String thinkzonLogoAsset = 'assets/logo.jpg';
  static const Color primaryColor = Color(0xFF0077B6);
  static const Color secondaryColor = Color(0xFFE65100);
}

/// What "Get Started" does: set by the app (opens the student main page).
void Function(BuildContext context)? lxOnGetStarted;
void lxGetStarted(BuildContext context) => lxOnGetStarted?.call(context);
