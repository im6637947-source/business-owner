import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ المكتبة الجديدة
import 'package:path_provider/path_provider.dart'; 
import 'package:excel/excel.dart'; 
import 'package:open_file/open_file.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; 

class BusinessController with ChangeNotifier {
  // ✅ الوصول لعميل Supabase
  final _supabase = Supabase.instance.client;
  
  // --- القوائم ---
  List<Map<String, dynamic>> _allTransactions = []; 
  List<Map<String, dynamic>> displayedTransactions = []; 
  
  List<Map<String, dynamic>> get transactions => _allTransactions;

  List<Map<String, dynamic>> orders = []; 
  List<Map<String, dynamic>> displayedOrders = [];
  List<Map<String, dynamic>> clients = [];
  List<Map<String, dynamic>> shippingCompanies = []; 

  // --- التحديد ---
  Set<int> selectedOrderIds = {}; 
  bool isSelectionMode = false;
  Set<int> selectedTransactionIds = {};
  bool get isTransactionSelectionMode => selectedTransactionIds.isNotEmpty;

  // --- الإجماليات ---
  double totalBalance = 0.0;
  double totalIncome = 0.0;
  double totalExpense = 0.0;

  // --- الفلاتر ---
  String currentFilter = 'all';
  String? currentDateFilter; 

  // 🔔 إعداد الإشعارات
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // ✅ دالة البدء (مبقتش تنشئ جداول، بقت تجيب داتا بس)
  Future<void> initDB() async {
    try {
      // إعداد الإشعارات
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      // جلب البيانات من السيرفر
      await fetchData();
      checkLateOrdersNotification(); 
    } catch (e) {
      debugPrint("❌ Init Error: $e");
    }
  }

  Future<void> fetchData() async {
    await fetchTransactions();
    await fetchOrders();
    await fetchClients();
    await fetchShippingCompanies();
  }

  // ================== AI Section ==================
  Future<Map<String, dynamic>?> analyzeOrderText(String text) async {
    return await AiService.analyzeText(text);
  }

  // ================== Shipping Companies ==================
  Future<void> fetchShippingCompanies() async {
    try {
      final response = await _supabase.from('shipping_companies').select().order('id');
      shippingCompanies = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error fetching companies: $e");
    }
  }

  Future<void> addShippingCompany(String name, String phone) async {
    await _supabase.from('shipping_companies').insert({'name': name, 'phone': phone});
    await fetchShippingCompanies();
  }

  Future<void> deleteShippingCompany(int id) async {
    await _supabase.from('shipping_companies').delete().eq('id', id);
    await fetchShippingCompanies();
  }

  // ================== Clients Logic ==================
  Future<void> fetchClients() async {
    try {
      final response = await _supabase.from('clients').select().order('id', ascending: false);
      clients = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error fetching clients: $e");
    }
  }

  // ================== Orders Logic ==================
  
  bool isOrderLate(Map<String, dynamic> order) {
    if (order['status'] != 'تم الشحن') return false; 
    if (order['date'] == null) return false;

    DateTime orderDate = DateTime.parse(order['date']);
    DateTime now = DateTime.now();
    return now.difference(orderDate).inDays >= 3;
  }

  Future<void> checkLateOrdersNotification() async {
    int lateCount = orders.where((o) => isOrderLate(o)).length;
    if (lateCount > 0) {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'late_orders', 'Late Orders Channel',
        importance: Importance.max, priority: Priority.high,
      );
      const NotificationDetails details = NotificationDetails(android: androidDetails);
      await flutterLocalNotificationsPlugin.show(
        0, '⚠️ تنبيه هام', 
        'لديك $lateCount شحنات متأخرة (أكثر من 3 أيام)!', 
        details
      );
    }
  }

  Future<void> fetchOrders() async {
    try {
      // ✅ ربط الجداول في Supabase (Foreign Key)
      // بنجيب الأوردر + بيانات العميل المرتبط بيه
      final response = await _supabase
          .from('orders')
          .select('*, clients(name, phone, address, governorate, region)')
          .order('date', ascending: false);

      // تحويل البيانات لشكل مسطح (Flat) عشان الكود القديم يشتغل زي ما هو
      orders = response.map((e) {
        final client = e['clients'] != null ? e['clients'] as Map<String, dynamic> : {};
        return {
          ...e,
          'client_name': client['name'] ?? 'Unknown',
          'client_phone': client['phone'] ?? '',
          'client_address': client['address'] ?? '',
          'client_gov': client['governorate'] ?? '',
          'client_region': client['region'] ?? '',
        };
      }).toList();

      filterOrders(); 
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error fetching orders: $e");
    }
  }

  void filterOrders({String query = '', String status = 'All', String? date, String? company}) {
    displayedOrders = orders.where((order) {
      bool queryMatch = order['client_name'].toString().toLowerCase().contains(query.toLowerCase()) || 
                        order['client_phone'].toString().contains(query);
      bool statusMatch = (status == 'All') || (order['status'] == status);
      bool dateMatch = true;
      if (date != null) {
        dateMatch = order['date'].toString().startsWith(date);
      }
      bool companyMatch = true;
      if (company != null && company != 'الكل') {
        companyMatch = order['shipping_company'] == company;
      }
      return statusMatch && queryMatch && dateMatch && companyMatch;
    }).toList();
    notifyListeners();
  }

  Future<void> addOrder(
      String name, String phone, String addr, 
      String gov, String region, 
      String details, String notes, 
      double price, double shippingCost, double deposit,
      String shippingCompany,
      {String? date} 
      ) async {
    
    // 1. إضافة العميل والحصول على الـ ID بتاعه
    final clientRes = await _supabase.from('clients').insert({
      'name': name, 'phone': phone, 'address': addr, 'governorate': gov, 'region': region
    }).select(); // .select() مهمة عشان ترجع الداتا المضافة
    
    final int clientId = clientRes[0]['id'];

    // 2. إضافة الأوردر
    await _supabase.from('orders').insert({
      'client_id': clientId, 'details': details, 'notes': notes,
      'total_price': price, 'shipping_cost': shippingCost, 'deposit': deposit,
      'shipping_company': shippingCompany,
      'status': 'قيد التجهيز', 
      'date': date ?? DateTime.now().toIso8601String().split('T')[0],
    });

    // 3. إضافة العربون للخزنة
    if (deposit > 0) {
      await addTransaction('عربون أوردر - $name', deposit, true);
    }
    await fetchData(); 
  }

  // ✅ تعديل: تحديث الأوردر + المنطق المالي (Supabase Version)
  Future<void> updateOrder(
      int id, String name, String phone, String addr,
      String gov, String region,
      String details, String notes, 
      double price, double ship, double deposit,
      String shippingCompany,
      {String? date}
      ) async {

    // 1. جلب البيانات القديمة
    final oldOrderRes = await _supabase
        .from('orders')
        .select('deposit, client_id, clients(name)')
        .eq('id', id)
        .single();
    
    if (oldOrderRes != null) {
      double oldDeposit = (oldOrderRes['deposit'] ?? 0).toDouble();
      String oldName = oldOrderRes['clients']['name'] ?? '';

      // 2. منطق تحديث الخزنة
      if (oldDeposit != deposit || oldName != name) {
        if (deposit == 0) {
          await _supabase.from('transactions').delete().match({'title': 'عربون أوردر - $oldName', 'amount': oldDeposit});
        } 
        else if (oldDeposit == 0 && deposit > 0) {
          await addTransaction('عربون أوردر - $name', deposit, true);
        }
        else {
          await _supabase.from('transactions')
              .update({'title': 'عربون أوردر - $name', 'amount': deposit})
              .match({'title': 'عربون أوردر - $oldName', 'amount': oldDeposit});
        }
      }

      // 3. تحديث العميل والأوردر
      int clientId = oldOrderRes['client_id'];
      await _supabase.from('clients').update({
        'name': name, 'phone': phone, 'address': addr, 'governorate': gov, 'region': region
      }).eq('id', clientId);

      Map<String, dynamic> updateData = {
        'details': details, 'notes': notes, 'total_price': price,
        'shipping_cost': ship, 'deposit': deposit,
        'shipping_company': shippingCompany
      };
      if(date != null) updateData['date'] = date;

      await _supabase.from('orders').update(updateData).eq('id', id);
    }
    await fetchData();
  }

  Future<void> updateOrderStatus(int id, String newStatus) async {
    await _supabase.from('orders').update({'status': newStatus}).eq('id', id);
    await fetchOrders(); 
  }
  
  // ✅ حذف الأوردر (Supabase Version)
  Future<void> deleteOrder(int id) async {
    // 1. هات الداتا قبل الحذف
    final orderRes = await _supabase
        .from('orders')
        .select('deposit, clients(name)')
        .eq('id', id)
        .maybeSingle();

    if (orderRes != null) {
      String clientName = orderRes['clients']['name'];
      double deposit = (orderRes['deposit'] ?? 0).toDouble();

      // 2. امسح العربون من الخزنة
      if (deposit > 0) {
        await _supabase.from('transactions').delete().match({
          'title': 'عربون أوردر - $clientName',
          'amount': deposit
        });
      }
    }

    // 3. امسح الأوردر
    await _supabase.from('orders').delete().eq('id', id);
    await fetchData();
  }

  Future<void> updateOrderDeposit(int orderId, double newTotalDeposit) async {
    final result = await _supabase.from('orders').select('deposit, client_id').eq('id', orderId).single();
    
    double oldDeposit = (result['deposit'] ?? 0).toDouble();
    int clientId = result['client_id'];
    double difference = newTotalDeposit - oldDeposit;

    await _supabase.from('orders').update({'deposit': newTotalDeposit}).eq('id', orderId);

    if (difference > 0) {
       final clientRes = await _supabase.from('clients').select('name').eq('id', clientId).single();
       String clientName = clientRes['name'];
       await addTransaction('تحصيل متبقي - $clientName', difference, true);
    }
    await fetchData(); 
  }

  // ================== Transactions Logic ==================
  
  void filterTransactions({String type = 'all', String? date}) {
    currentFilter = type;
    currentDateFilter = date;

    if (_allTransactions.isEmpty) {
      displayedTransactions = [];
      notifyListeners();
      return;
    }

    displayedTransactions = _allTransactions.where((trans) {
      bool typeMatch = true;
      if (type == 'income') typeMatch = trans['isIncome'] == 1;
      if (type == 'expense') typeMatch = trans['isIncome'] == 0;

      bool dateMatch = true;
      if (date != null && date.isNotEmpty) {
        if (trans['date'] != null) {
          dateMatch = trans['date'].toString().startsWith(date);
        } else {
          dateMatch = false;
        }
      }
      return typeMatch && dateMatch;
    }).toList();
    
    notifyListeners();
  }

  Future<void> fetchTransactions() async {
    try {
      final response = await _supabase.from('transactions').select().order('date', ascending: false);
      _allTransactions = List<Map<String, dynamic>>.from(response);
      
      totalIncome = 0.0; totalExpense = 0.0;
      for (var item in _allTransactions) {
        double amt = (item['amount'] ?? 0).toDouble();
        if (item['isIncome'] == 1) totalIncome += amt; else totalExpense += amt;
      }
      totalBalance = totalIncome - totalExpense;
      
      filterTransactions(type: currentFilter, date: currentDateFilter); 
    } catch (e) {
      debugPrint("❌ Error fetching transactions: $e");
    }
  }

  Future<bool> addTransaction(String title, double amount, bool isIncome) async {
    try {
      await _supabase.from('transactions').insert({
        'title': title, 
        'amount': amount, 
        'isIncome': isIncome ? 1 : 0,
        'date': DateTime.now().toIso8601String(), 
        'type': 'General'
      });
      await fetchTransactions();
      return true;
    } catch (e) { return false; }
  }

  Future<void> deleteTransaction(int id) async {
    await _supabase.from('transactions').delete().eq('id', id);
    await fetchTransactions();
  }

  Future<void> updateTransaction(int id, String title, double amount, bool isIncome) async {
      await _supabase.from('transactions').update({
        'title': title, 
        'amount': amount, 
        'isIncome': isIncome ? 1 : 0
      }).eq('id', id);
      await fetchTransactions();
  }

  // --- دوال التحديد (زي ما هي) ---
  void toggleOrderSelection(int id) { if (selectedOrderIds.contains(id)) selectedOrderIds.remove(id); else selectedOrderIds.add(id); isSelectionMode = selectedOrderIds.isNotEmpty; notifyListeners(); }
  void selectAllOrders() { selectedOrderIds = displayedOrders.map((o) => o['id'] as int).toSet(); isSelectionMode = true; notifyListeners(); }
  void clearSelection() { selectedOrderIds.clear(); isSelectionMode = false; notifyListeners(); }
  void toggleTransactionSelection(int id) { if (selectedTransactionIds.contains(id)) selectedTransactionIds.remove(id); else selectedTransactionIds.add(id); notifyListeners(); }
  void selectAllTransactions() { selectedTransactionIds = displayedTransactions.map((e) => e['id'] as int).toSet(); notifyListeners(); }
  void clearTransactionSelection() { selectedTransactionIds.clear(); notifyListeners(); }

  // --- تصدير الأوردرات للإكسيل (زي ما هي) ---
  Future<void> exportSelectedToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Orders'];
    
    sheetObject.appendRow([
      TextCellValue('رقم الأوردر'), 
      TextCellValue('التاريخ'),
      TextCellValue('العميل'), 
      TextCellValue('الموبايل'), 
      TextCellValue('المحافظة'), 
      TextCellValue('المنطقة'), 
      TextCellValue('العنوان'), 
      TextCellValue('المنتجات'), 
      TextCellValue('ملاحظات'),
      TextCellValue('الإجمالي'), 
      TextCellValue('المدفوع'),
      TextCellValue('المتبقي'),
      TextCellValue('شركة الشحن'), 
      TextCellValue('الحالة')
    ]);

    List<Map<String, dynamic>> selectedList = isSelectionMode
        ? orders.where((o) => selectedOrderIds.contains(o['id'])).toList()
        : displayedOrders;
    
    for (var order in selectedList) {
      double total = (order['total_price'] ?? 0) + (order['shipping_cost'] ?? 0);
      double deposit = (order['deposit'] ?? 0).toDouble();
      double remaining = total - deposit;

      sheetObject.appendRow([
        IntCellValue(order['id']),
        TextCellValue(order['date'] ?? ''),
        TextCellValue(order['client_name']),
        TextCellValue(order['client_phone']),
        TextCellValue(order['client_gov'] ?? ''),
        TextCellValue(order['client_region'] ?? ''),
        TextCellValue(order['client_address']),
        TextCellValue(order['details']),
        TextCellValue(order['notes'] ?? ''),
        DoubleCellValue(total),      
        DoubleCellValue(deposit),    
        DoubleCellValue(remaining),  
        TextCellValue(order['shipping_company'] ?? ''),
        TextCellValue(order['status'])
      ]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/Orders_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
      await OpenFile.open(path);
    }
    clearSelection();
  }

  // --- تصدير الحركات المالية للإكسيل ---
  Future<void> exportTransactionsToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Finance'];

    sheetObject.appendRow([
      TextCellValue('م'), 
      TextCellValue('التاريخ'), 
      TextCellValue('الوصف'), 
      TextCellValue('نوع الحركة'), 
      TextCellValue('المبلغ')
    ]);

    List<Map<String, dynamic>> listToExport = isTransactionSelectionMode
        ? _allTransactions.where((t) => selectedTransactionIds.contains(t['id'])).toList()
        : displayedTransactions;

    for (var trans in listToExport) {
      sheetObject.appendRow([
        IntCellValue(trans['id']),
        TextCellValue(trans['date'].toString().split('T')[0]),
        TextCellValue(trans['title']),
        TextCellValue(trans['isIncome'] == 1 ? 'إيراد' : 'مصروف'),
        DoubleCellValue((trans['amount'] ?? 0).toDouble())
      ]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/Finance_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
      await OpenFile.open(path);
    }
    clearTransactionSelection();
  }
}

// ================== AI Service ==================
class AiService {
  // ⚠️⚠️⚠️ مفتاحك كما هو ⚠️⚠️⚠️
  static const String _apiKey = 'AIzaSyALkuePnIpmlRWV3maMomoxKBCzj6A-PsA';

  static Future<Map<String, dynamic>?> analyzeText(String text) async {
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final prompt = '''
        You are an intelligent order parser.
        Analyze the following text (Arabic or English) and extract the data into a strict JSON object.
        
        Rules:
        - "name": Client Name (or "Unknown").
        - "phone": Extract phone number, convert Eastern Arabic digits (٠١٢) to Western (012). Only digits.
        - "price": Total Price as a NUMBER (e.g. 150.0). If not found, use 0.
        - "gov": Governorate/Province.
        - "region": City/District/Area.
        - "address": Detailed street address.
        - "details": Summary of items ordered.

        Input Text: """$text"""
      ''';
      
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      if (response.text != null) {
        String cleanJson = response.text!.trim();
        if (cleanJson.startsWith('```json')) {
          cleanJson = cleanJson.replaceAll('```json', '').replaceAll('```', '');
        }
        return jsonDecode(cleanJson);
      }
    } catch (e) { debugPrint("AI Error: $e"); }
    return null;
  }
}