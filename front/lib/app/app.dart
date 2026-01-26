import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import '../utils/page_transitions.dart';
import '../utils/keyboard_height_service.dart';
import '../widgets/global/global_logo_bar.dart';
import '../widgets/global/global_bottom_bar.dart';
import '../widgets/global/ai_search_overlay.dart';
import '../pages/main_page.dart';
import '../analytics.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static final RouteObserver<PageRoute<dynamic>> routeObserver =
      RouteObserver<PageRoute<dynamic>>();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialize theme from Telegram WebApp
    AppTheme.initialize();
    
    // Initialize keyboard height service (JavaScript-based, no MediaQuery)
    KeyboardHeightService().initialize();
    
    // Initialize Vercel Analytics after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VercelAnalytics.init();
      // Track initial page view
      VercelAnalytics.trackPageView(path: '/', title: 'Home');
      
      // WebApp is already initialized in main() via tma.WebApp().init()
    });
  }
  
  @override
  void dispose() {
    // Clean up listener if needed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to theme changes and rebuild when theme changes
    return ValueListenableBuilder<String?>(
      valueListenable: AppTheme.colorSchemeNotifier,
      builder: (context, colorScheme, child) {
        return MaterialApp(
          title: "Hype N' Links",
          navigatorKey: MyApp.navigatorKey,
          navigatorObservers: [MyApp.routeObserver],
          builder: (context, child) {
            // Architecture: Independent overlays for top/bottom bars
            // - Top bar (GlobalLogoBar): Positioned at top, can hide/show dynamically
            // - Bottom bar (GlobalBottomBar): Positioned at bottom, moves with keyboard
            // - Main content: Pages handle their own padding using helper methods
            // 
            // KEY FIX: resizeToAvoidBottomInset: false prevents Scaffold from resizing
            // when keyboard opens. This stops page content from rebuilding/reloading.
            // Instead, bottom bar positions itself using MediaQuery.viewInsets.bottom
            // to detect keyboard height and move independently.
            return Scaffold(
              resizeToAvoidBottomInset: false, // CRITICAL: Prevents page reload on keyboard
              backgroundColor: AppTheme.backgroundColor,
              body: Stack(
                children: [
                  // Main content (pages) - base layer, NEVER rebuilds when keyboard opens
                  // Pages use GlobalLogoBar.getContentTopPadding() for top spacing
                  child ?? const SizedBox.shrink(),
                  
                  // Top bar overlay - independent positioning
                  // Hides/shows in Telegram based on fullscreen mode
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: GlobalLogoBar(),
                  ),
                  
                  // Isolated MediaQuery detection widget
                  // This widget rebuilds when keyboard opens/closes, but it's isolated
                  // Only this widget rebuilds, not the Stack or page content
                  // Updates KeyboardHeightService.heightNotifier when keyboard height changes
                  _KeyboardHeightDetector(),
                  
                  // AI search overlay - positioned below logo bar
                  // Uses keyboard height to center options in visible area
                  ValueListenableBuilder<double>(
                    valueListenable: KeyboardHeightService().heightNotifier,
                    builder: (context, keyboardHeight, child) {
                      return Positioned(
                        top: GlobalLogoBar.getLogoBlockHeight(),
                        left: 0,
                        right: 0,
                        bottom: keyboardHeight, // Exclude keyboard area for proper centering
                        child: child ?? const AiSearchOverlay(),
                      );
                    },
                    child: const AiSearchOverlay(),
                  ),
                  
                  // Bottom bar overlay - moves with keyboard
                  ValueListenableBuilder<double>(
                    valueListenable: KeyboardHeightService().heightNotifier,
                    builder: (context, keyboardHeight, child) {
                      return Positioned(
                        bottom: keyboardHeight,
                        left: 0,
                        right: 0,
                        child: child ?? const GlobalBottomBar(),
                      );
                    },
                    child: const GlobalBottomBar(),
                  ),
                ],
              ),
            );
          },
          // Use default theme without Material fonts to avoid loading errors
          theme: ThemeData(
            useMaterial3: false,
            scaffoldBackgroundColor: AppTheme.backgroundColor,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: NoAnimationPageTransitionsBuilder(),
                TargetPlatform.iOS: NoAnimationPageTransitionsBuilder(),
                TargetPlatform.macOS: NoAnimationPageTransitionsBuilder(),
                TargetPlatform.windows: NoAnimationPageTransitionsBuilder(),
                TargetPlatform.linux: NoAnimationPageTransitionsBuilder(),
                TargetPlatform.fuchsia: NoAnimationPageTransitionsBuilder(),
              },
            ),
            fontFamily: 'Aeroport',
            textTheme: TextTheme(
              bodyLarge: TextStyle(
                  fontFamily: 'Aeroport',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor),
              bodyMedium: TextStyle(
                  fontFamily: 'Aeroport',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor),
              bodySmall: TextStyle(
                  fontFamily: 'Aeroport',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor),
              displayLarge: TextStyle(
                  fontFamily: 'Aeroport',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor),
              displayMedium: TextStyle(
                  fontFamily: 'Aeroport',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor),
              displaySmall: TextStyle(
                  fontFamily: 'Aeroport',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor),
              headlineLarge: TextStyle(
                  fontFamily: 'Aeroport',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor),
              headlineMedium: TextStyle(
                  fontFamily: 'Aeroport',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor),
              headlineSmall: TextStyle(
                  fontFamily: 'Aeroport',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor),
              titleLarge: TextStyle(
                  fontFamily: 'Aeroport',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor),
              titleMedium: TextStyle(
                  fontFamily: 'Aeroport',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor),
              titleSmall: TextStyle(
                  fontFamily: 'Aeroport',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor),
              labelLarge: TextStyle(
                  fontFamily: 'Aeroport',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor),
              labelMedium: TextStyle(
                  fontFamily: 'Aeroport',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor),
              labelSmall: TextStyle(
                  fontFamily: 'Aeroport',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor),
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: TextStyle(
              fontFamily: 'Aeroport',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor),
          hintStyle: TextStyle(
              fontFamily: 'Aeroport',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thickness: WidgetStateProperty.all(0.0),
          thumbVisibility: WidgetStateProperty.all(false),
          trackVisibility: WidgetStateProperty.all(false),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const MainPage(),
        );
      },
    );
  }
}

/// Isolated widget that detects keyboard height using MediaQuery
/// This widget rebuilds when keyboard opens/closes, but it's isolated from Stack
/// Only this widget rebuilds, preventing page content from reloading
/// Works on all platforms: native, browser, and TMA
class _KeyboardHeightDetector extends StatefulWidget {
  const _KeyboardHeightDetector();

  @override
  State<_KeyboardHeightDetector> createState() => _KeyboardHeightDetectorState();
}

class _KeyboardHeightDetectorState extends State<_KeyboardHeightDetector> {
  double _lastHeight = 0.0;

  @override
  Widget build(BuildContext context) {
    // Read MediaQuery - this causes THIS widget to rebuild when keyboard opens/closes
    // But since it's isolated, the Stack doesn't rebuild
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    // Update service notifier only if value changed
    // Using post-frame callback to avoid updating during build phase
    if ((_lastHeight - keyboardHeight).abs() > 0.1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _lastHeight = keyboardHeight;
          KeyboardHeightService().heightNotifier.value = keyboardHeight;
          print('[KeyboardHeightDetector] Keyboard height detected: ${keyboardHeight}px');
        }
      });
    }
    
    // Return invisible widget - this widget rebuilds but has no visual impact
    return const SizedBox.shrink();
  }
}
