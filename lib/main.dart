import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart'; 
import 'package:provider/provider.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:url_strategy/url_strategy.dart'; 

// ✅ تأكد من مسارات الملفات دي عندك
import 'controllers/business_controller.dart'; 
import 'screen/home_layout.dart'; 
import 'screen/shipping_companies_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تحسين الروابط
  setPathUrlStrategy();

  // 2. تهيئة التواريخ
  await initializeDateFormatting();

  try {
    // 3. تهيئة Supabase (حط المفتاح الصح هنا)
    await Supabase.initialize(
      url: 'https://tmjnwfezpuizqzabslno.supabase.co', 
      // 🛑 روح موقع Supabase -> Project Settings -> API -> انسخ anon public key
      // لازم يبدأ بـ eyJxhBg...
      anonKey: 'sb_publishable_1p196b893_uwodm-9dihgA_TKIFraxh', 
    );
  } catch (e) {
    // 🛑 لو حصل خطأ في الاتصال (نت مقطوع مثلاً) التطبيق هيعرض رسالة بدل ما يقفل
    runApp(ErrorScreen(error: e.toString()));
    return;
  }

  runApp(
    ChangeNotifierProvider(
      // 🔥 ممتاز: بنحمل البيانات أول ما يفتح
      create: (_) => BusinessController()..initDB(), 
      child: const MyBusinessApp(),
    ),
  );
}

class MyBusinessApp extends StatelessWidget {
  const MyBusinessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Business Pro',
      locale: const Locale('ar', 'EG'),
      
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        primaryColor: const Color(0xFF1A237E),

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          primary: const Color(0xFF1A237E),
          secondary: const Color(0xFFFFC107),
          error: const Color(0xFFD32F2F),
        ),
        
        textTheme: GoogleFonts.cairoTextTheme(Theme.of(context).textTheme),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0, 
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.black87), 
          titleTextStyle: TextStyle(
            color: Colors.black87, 
            fontSize: 20, 
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo' 
          ),
        ),

        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 2,
          margin: EdgeInsets.only(bottom: 12),
          surfaceTintColor: Colors.white, 
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E), 
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300), 
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2), 
          ),
        ),
      ),
      
      routes: {
        '/': (context) => const HomeLayout(),
        '/shipping': (context) => const ShippingCompaniesScreen(),
      },
      
      initialRoute: '/', 
    );
  }
}

// شاشة طوارئ تظهر لو النت قاطع أو المفاتيح غلط
class ErrorScreen extends StatelessWidget {
  final String error;
  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text("فشل بدء التطبيق", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}