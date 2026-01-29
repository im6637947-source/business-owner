import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart'; 
import 'package:provider/provider.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:url_strategy/url_strategy.dart'; 

// ✅ استدعاء الشاشات والكنترولر
import 'controllers/business_controller.dart'; 
import 'screen/home_layout.dart'; 
import 'screen/shipping_companies_screen.dart'; // 🚚 استدعاء صفحة الشركات

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تفعيل الروابط النضيفة
  setPathUrlStrategy();

  // 2. تفعيل التواريخ
  await initializeDateFormatting();

  // 3. تهيئة Supabase
  await Supabase.initialize(
    url: 'https://tmjnwfezpuizqzabslno.supabase.co', 
    anonKey: 'sb_publishable_1p196b893_uwodm-9dihgA_TKIFraxh', 
  );

  runApp(
    ChangeNotifierProvider(
      // 🔥 تعديل مهم: بننادي على fetchData عشان يحمل البيانات أول ما يفتح
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
      
      // ✅ تعريف الروت عشان التنقل يشتغل صح
      routes: {
        '/': (context) => const HomeLayout(),
        '/shipping': (context) => const ShippingCompaniesScreen(),
      },
      
      initialRoute: '/', // نقطة البداية
    );
  }
}