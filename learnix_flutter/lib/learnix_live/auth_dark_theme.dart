import 'package:flutter/material.dart';
import 'lx_brand.dart';

/// Shared light palette + soft geometric background for the auth flow --
/// Welcome, Login, Sign Up, Set Password and Forgot Password all use this
/// exact palette so the whole pre-login flow reads as one consistent
/// experience: a white background, faint geometric line/shape decoration,
/// and OTOMATIKS blue (BrandConfig.primaryColor, #0077B6) as the single
/// accent color. Replaces the earlier dark "at night" palette per explicit
/// feedback that the dark theme wasn't wanted -- kept the class name so the
/// four screens that import this file didn't need their import paths
/// touched, only the palette + shapes underneath it.
///
/// Scoped to the auth flow only: the rest of the app (every CRM/LMS/ERP
/// dashboard screen) stays on AppTheme's existing light theme.
class AuthTheme {
  AuthTheme._();

  static const bg = Color(0xFFFFFFFF);
  static const blue = BrandConfig.primaryColor; // #0077B6
  static const blueLight = Color(0xFF4CC9F0);
  static const blueDeep = Color(0xFF023047);
  static const ink = Color(0xFF0F1F2E);
  static const textMuted = Color(0xFF64748B);
  static const cardBg = Colors.white;
  static const cardBorder = Color(0xFFE3EAF0);
  static const fieldBg = Color(0xFFF7FAFC);
  static const fieldBorder = Color(0xFFE2E8F0);

  static const cardShadow = [
    BoxShadow(color: Color(0x14063A5C), blurRadius: 32, offset: Offset(0, 16)),
  ];

  /// The full-bleed white background + faint geometric line art used behind
  /// every auth screen's content -- a Stack fragment meant to sit as the
  /// first/bottom children of a Scaffold's body Stack, with the real screen
  /// content layered on top. Uses the project's own bg_branding.png asset
  /// (a soft white-to-pale-blue hexagon grid with a couple of faint circuit
  /// traces) rather than a hand-drawn pattern, since that asset already is
  /// the "white background with geometric lines" look and is on-brand.
  static List<Widget> backgroundLayers() {
    return [
      const Positioned.fill(child: ColoredBox(color: bg)),
      Positioned.fill(
        child: Image.asset(
          'assets/bg_branding.png',
          fit: BoxFit.cover,
        ),
      ),
    ];
  }

  /// The pinned top bar shared by every auth screen -- logo + wordmark,
  /// thin bottom border, optional back button (Login/Sign Up/Set Password
  /// all navigate "back" to Welcome or the previous auth step; Welcome
  /// itself is the root of the flow and passes showBack: false).
  static Widget topBar(BuildContext context, {bool showBack = false, VoidCallback? onBack}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: cardBorder)),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            IconButton(
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, color: ink),
            ),
            const SizedBox(width: 4),
          ],
          // The logo asset is now the full "Learnix" wordmark (text +
          // tagline) rather than a standalone icon mark, so it replaces
          // the old icon-circle + separate app-name Text entirely instead
          // of sitting next to it -- showing both would just repeat the
          // word "Learnix" twice. Background here is white (see this
          // Container's own decoration above), so the wordmark's dark
          // navy text reads fine with no backing chip needed.
          Image.asset(BrandConfig.logoAsset, height: 34, fit: BoxFit.contain),
          const Spacer(),
          // "Powered by OTOMATIKS" -- this app is OTOMATIKS's own ERP
          // (see BrandConfig.companyNameLower), so every screen sharing
          // this top bar carries their wordmark, not just the Learnix
          // product name. The "Powered by" label only shows once there's
          // room for it (a phone-width screen already has the back
          // button + logo + app name competing for space here) -- the
          // logo image itself always shows regardless of width.
          if (MediaQuery.of(context).size.width >= 480) ...[
            Text('Powered by', style: TextStyle(color: textMuted.withOpacity(0.8), fontSize: 10.5, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
          ],
          // thinkzon logo, shown exactly as supplied (its navy background is kept). Falls back to
          // a text wordmark if the asset file is missing.
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              BrandConfig.thinkzonLogoAsset,
              height: 34,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  children: [
                    TextSpan(text: 'think', style: TextStyle(color: Color(0xFF0B3C5D))),
                    TextSpan(text: 'zon', style: TextStyle(color: Color(0xFF0077B6))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shared InputDecoration for text fields on the auth screens -- soft
  /// tinted fill, faint border, OTOMATIKS-blue focus border, so every field
  /// across Login/Sign Up/Set Password looks the same without copy-pasting
  /// this decoration into each file.
  static InputDecoration fieldDecoration({required String hint, required IconData icon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: textMuted),
      prefixIcon: Icon(icon, color: textMuted, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: fieldBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: fieldBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: blue, width: 1.6)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFEF4444))),
    );
  }
}
