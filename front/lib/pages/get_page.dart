import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app/theme/app_theme.dart';
import '../widgets/global/global_logo_bar.dart';
import '../widgets/common/edge_swipe_back.dart';
import '../telegram_safe_area.dart';
import '../utils/app_haptic.dart';

class GetPage extends StatefulWidget {
  const GetPage({super.key});

  @override
  State<GetPage> createState() => _GetPageState();
}

class _GetPageState extends State<GetPage> {
  static const String _addressText =
      'EQCNT_JdH8Vc\n-kJyr_-HhBge\n7JpMMiR8X8yn\nsUJalr_qRiKE';

  Future<void> _copyAddress() async {
    await Clipboard.setData(const ClipboardData(text: _addressText));
    AppHaptic.heavy();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address copied'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  double _getAdaptiveBottomPadding() {
    final service = TelegramSafeAreaService();
    final safeAreaInset = service.getSafeAreaInset();
    return safeAreaInset.bottom + 30;
  }

  double _getGlobalBottomBarHeight() {
    return 10.0 + 30.0 + 15.0;
  }

  void _handleBackButton() {
    AppHaptic.heavy();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = GlobalLogoBar.getContentTopPadding();
    final bottomBarHeight = _getGlobalBottomBarHeight();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: EdgeSwipeBack(
        onBack: _handleBackButton,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: topPadding,
                left: 15,
                right: 15,
                bottom: _getAdaptiveBottomPadding() + bottomBarHeight,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 570),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              '..xk5str4e',
                              style: TextStyle(
                                fontFamily: 'Aeroport Mono',
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF818181),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Sendal Rodriges',
                                  style: TextStyle(
                                    fontFamily: 'Aeroport',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF818181),
                                    height: 1.0,
                                  ),
                                  textHeightBehavior: TextHeightBehavior(
                                    applyHeightToFirstAscent: false,
                                    applyHeightToLastDescent: false,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                SvgPicture.asset(
                                  'assets/icons/select.svg',
                                  width: 5,
                                  height: 10,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned.fill(
                        child: Center(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _copyAddress,
                            child: const Text(
                              _addressText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 30,
                                height: 55 / 30,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF1111FF),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
