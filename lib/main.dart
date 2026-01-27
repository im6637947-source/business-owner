import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart'; 
import 'package:provider/provider.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ إضافة مكتبة سوبابيز
import 'package:url_strategy/url_strategy.dart'; // ✅ عشان الروابط في الويب تبقى نضيفة
import 'screen/home_layout.dart'; 
import 'controllers/business_controller.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 1. تفعيل وضع الروابط النضيفة للويب (بيشيل حرف # من المتصفح)
  setPathUrlStrategy();

  // ✅ 2. تفعيل التواريخ والعملات
  await initializeDateFormatting();

  // ✅ 3. الربط مع Supabase (حط بيانات مشروعك هنا)
  await Supabase.initialize(
    url: 'https://tmjnwfezpuizqzabslno.supabase.co', // 👈 حط الـ Project URL بتاعك هنا
    anonKey: 'sb_publishable_1p196b893_uwodm-9dihgA_TKIFraxh', // 👈 حط الـ Anon Key بتاعك هنا
  );

  // ملاحظة: شيلنا controller.initDB() لأن سوبابيز مش محتاجة إنشاء ملف محلي
  runApp(
    ChangeNotifierProvider(
      create: (_) => BusinessController(),
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
      
      // ✅ دعم اللغة العربية في التطبيق بالكامل
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
        
        // الخط العربي (القاهرة)
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
      
      home: const HomeLayout(), 
    );
  }
}