import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_constants.dart';
import 'core/di/injection.dart';
import 'core/network/signalr_service.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_service.dart';
import 'core/utils/token_utils.dart';

void main() async {
  // Đảm bảo Flutter framework được nạp xong trước khi cấu hình hệ thống ngoài
  WidgetsFlutterBinding.ensureInitialized();

  // Tối ưu hóa UI hệ thống (Thanh trạng thái trong suốt)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Khởi tạo toàn bộ Dependency Injection (Mạng, Cơ sở dữ liệu)
  try {
    await configureDependencies();
  } catch (e) {
    print('Lỗi cấu hình Dependency Injection: $e');
  }

  // Kiểm tra token khi mở app: nếu hết hạn thì tự động xóa
  final prefs = await SharedPreferences.getInstance();
  final tokenValid = TokenUtils.validateAndCleanToken(prefs);

  // Nếu token còn hiệu lực -> kết nối SignalR ngay khi mở app
  if (tokenValid) {
    final token = prefs.getString(AppConstants.authTokenKey) ?? '';
    // Không await — kết nối ngầm, không chặn UI
    getIt<SignalRService>().connect(token).catchError((e) {
      debugPrint('[Main] SignalR auto-connect failed: $e');
    });
  }

  // Khởi tạo dịch vụ ngôn ngữ dựa trên SharedPreferences
  final localeService = LocaleService(prefs);

  runApp(
    ChangeNotifierProvider.value(
      value: localeService,
      child: const CoreApp(),
    ),
  );
}

class CoreApp extends StatelessWidget {
  const CoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleService>(
      builder: (context, localeService, child) {
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,

          // Cấu hình Theme hệ thống
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,

          // Đa ngôn ngữ cơ bản, chưa cần dùng
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: localeService.currentLocale,

          // Cấu hình định tuyến trung tâm GoRouter
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}