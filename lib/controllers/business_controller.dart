import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart'; 
import 'package:excel/excel.dart'; 
import 'package:open_file/open_file.dart'; 
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; 

class BusinessController with ChangeNotifier {
  Database? _database;
  
  // --- القوائم ---
  List<Map<String, dynamic>> _allTransactions = []; 
  List<Map<String, dynamic>> displayedTransactions = []; 
  
  // Getter عشان لو حبيت توصل لكل الحركات من برة
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

  Future<void> initDB() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      String path = join(await getDatabasesPath(), 'business_pro_v11.db'); 
      
      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, isIncome INTEGER, date TEXT, type TEXT)');
          await db.execute('CREATE TABLE clients(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT, address TEXT, governorate TEXT, region TEXT)');
          await db.execute('CREATE TABLE shipping_companies(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT)');
          await db.execute('CREATE TABLE orders(id INTEGER PRIMARY KEY AUTOINCREMENT, client_id INTEGER, details TEXT, notes TEXT, total_price REAL, shipping_cost REAL, deposit REAL, status TEXT, shipping_company TEXT, date TEXT)');
        },
      );
      
      await fetchData();
      checkLateOrdersNotification(); 
    } catch (e) {
      debugPrint("❌ DB Error: $e");
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
    if (_database == null) return;
    try {
      shippingCompanies = await _database!.query('shipping_companies');
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error fetching companies: $e");
    }
  }

  Future<void> addShippingCompany(String name, String phone) async {
    if (_database == null) return;
    await _database?.insert('shipping_companies', {'name': name, 'phone': phone});
    await fetchShippingCompanies();
  }

  Future<void> deleteShippingCompany(int id) async {
    if (_database == null) return;
    await _database?.delete('shipping_companies', where: 'id = ?', whereArgs: [id]);
    await fetchShippingCompanies();
  }

  // ================== Clients Logic ==================
  Future<void> fetchClients() async {
    if (_database == null) return;
    try {
      clients = await _database!.query('clients', orderBy: 'id DESC');
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
    if (_database == null) return;
    
    try {
      final List<Map<String, dynamic>> res = await _database!.rawQuery('''
        SELECT orders.*, 
               clients.name as client_name, 
               clients.phone as client_phone, 
               clients.address as client_address,
               clients.governorate as client_gov,
               clients.region as client_region
        FROM orders 
        INNER JOIN clients ON orders.client_id = clients.id 
        ORDER BY orders.date DESC
      ''');
      orders = res;
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
    if (_database == null) return;

    int clientId = await _database!.insert('clients', {
      'name': name, 'phone': phone, 'address': addr, 'governorate': gov, 'region': region
    });

    await _database?.insert('orders', {
      'client_id': clientId, 'details': details, 'notes': notes,
      'total_price': price, 'shipping_cost': shippingCost, 'deposit': deposit,
      'shipping_company': shippingCompany,
      'status': 'قيد التجهيز', 
      'date': date ?? DateTime.now().toIso8601String().split('T')[0],
    });

    if (deposit > 0) {
      await addTransaction('عربون أوردر - $name', deposit, true);
    }
    await fetchData(); 
  }

  // ✅ تعديل: تحديث الأوردر + تحديث/حذف الحركة المالية المرتبطة
  Future<void> updateOrder(
      int id, String name, String phone, String addr,
      String gov, String region,
      String details, String notes, 
      double price, double ship, double deposit,
      String shippingCompany,
      {String? date}
      ) async {
    if (_database == null) return;

    // 1. نجيب البيانات القديمة عشان نعرف العربون القديم والاسم القديم
    var oldOrderData = await _database!.rawQuery('''
      SELECT orders.deposit, clients.name 
      FROM orders 
      JOIN clients ON orders.client_id = clients.id 
      WHERE orders.id = ?
    ''', [id]);

    if (oldOrderData.isNotEmpty) {
      double oldDeposit = oldOrderData.first['deposit'] as double;
      String oldName = oldOrderData.first['name'] as String;

      // 2. تحديث الحركة المالية
      if (oldDeposit != deposit || oldName != name) {
        // لو العربون الجديد 0، امسح الحركة القديمة
        if (deposit == 0) {
          await _database!.delete('transactions', 
            where: 'title = ? AND amount = ?', 
            whereArgs: ['عربون أوردر - $oldName', oldDeposit]
          );
        } 
        // لو كان 0 وبقى رقم، ضيف حركة جديدة
        else if (oldDeposit == 0 && deposit > 0) {
          await addTransaction('عربون أوردر - $name', deposit, true);
        }
        // لو اتغير بس، حدث الحركة الموجودة
        else {
          await _database!.update('transactions', 
            {'title': 'عربون أوردر - $name', 'amount': deposit},
            where: 'title = ? AND amount = ?',
            whereArgs: ['عربون أوردر - $oldName', oldDeposit]
          );
        }
      }
    }

    // 3. تحديث بيانات العميل والأوردر
    var res = await _database!.query('orders', columns: ['client_id'], where: 'id = ?', whereArgs: [id]);
    if (res.isNotEmpty) {
      int clientId = res.first['client_id'] as int;
      await _database?.update('clients', {
        'name': name, 'phone': phone, 'address': addr, 'governorate': gov, 'region': region
      }, where: 'id = ?', whereArgs: [clientId]);

      Map<String, dynamic> updateData = {
        'details': details, 'notes': notes, 'total_price': price,
        'shipping_cost': ship, 'deposit': deposit,
        'shipping_company': shippingCompany
      };
      if(date != null) updateData['date'] = date;

      await _database?.update('orders', updateData, where: 'id = ?', whereArgs: [id]);
    }
    await fetchData();
  }

  Future<void> updateOrderStatus(int id, String newStatus) async {
    if (_database == null) return;
    await _database?.update('orders', {'status': newStatus}, where: 'id = ?', whereArgs: [id]);
    await fetchOrders(); 
  }
  
  // ✅ تعديل: حذف الأوردر + حذف الحركة المالية المرتبطة
  Future<void> deleteOrder(int id) async {
    if (_database == null) return;

    // 1. نجيب بيانات الأوردر قبل الحذف
    var orderRes = await _database!.rawQuery('''
      SELECT orders.deposit, clients.name 
      FROM orders 
      JOIN clients ON orders.client_id = clients.id 
      WHERE orders.id = ?
    ''', [id]);

    // 2. لو ليه عربون، نمسحه من الخزنة
    if (orderRes.isNotEmpty) {
      String clientName = orderRes.first['name'] as String;
      double deposit = orderRes.first['deposit'] as double;

      if (deposit > 0) {
        await _database!.delete(
          'transactions',
          where: 'title = ? AND amount = ?',
          whereArgs: ['عربون أوردر - $clientName', deposit]
        );
      }
    }

    // 3. حذف الأوردر نفسه
    await _database?.delete('orders', where: 'id = ?', whereArgs: [id]);
    await fetchData(); // تحديث شامل (عشان يسمع في الخزنة والشحنات)
  }

  Future<void> updateOrderDeposit(int orderId, double newTotalDeposit) async {
    if (_database == null) return;
    var result = await _database!.query('orders', columns: ['deposit', 'client_id'], where: 'id = ?', whereArgs: [orderId]);
    if (result.isNotEmpty) {
      double oldDeposit = result.first['deposit'] as double;
      int clientId = result.first['client_id'] as int;
      double difference = newTotalDeposit - oldDeposit;
      await _database?.update('orders', {'deposit': newTotalDeposit}, where: 'id = ?', whereArgs: [orderId]);
      if (difference > 0) {
          var clientRes = await _database!.query('clients', columns: ['name'], where: 'id = ?', whereArgs: [clientId]);
          String clientName = clientRes.isNotEmpty ? clientRes.first['name'] as String : 'عميل';
          await addTransaction('تحصيل متبقي - $clientName', difference, true);
      }
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
    if (_database == null) return; 

    try {
      _allTransactions = await _database!.query('transactions', orderBy: 'date DESC');
      
      totalIncome = 0.0; totalExpense = 0.0;
      for (var item in _allTransactions) {
        double amt = item['amount'];
        if (item['isIncome'] == 1) totalIncome += amt; else totalExpense += amt;
      }
      totalBalance = totalIncome - totalExpense;
      
      filterTransactions(type: currentFilter, date: currentDateFilter); 
    } catch (e) {
      debugPrint("❌ Error fetching transactions: $e");
    }
  }

  Future<bool> addTransaction(String title, double amount, bool isIncome) async {
    if (_database == null) return false;
    try {
      await _database?.insert('transactions', {
        'title': title, 'amount': amount, 'isIncome': isIncome ? 1 : 0,
        'date': DateTime.now().toIso8601String(), 'type': 'General'
      });
      await fetchTransactions();
      return true;
    } catch (e) { return false; }
  }

  Future<void> deleteTransaction(int id) async {
    if (_database == null) return;
    await _database?.delete('transactions', where: 'id = ?', whereArgs: [id]);
    await fetchTransactions();
  }

  Future<void> updateTransaction(int id, String title, double amount, bool isIncome) async {
      if (_database == null) return;
      await _database?.update('transactions', {'title': title, 'amount': amount, 'isIncome': isIncome ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
      await fetchTransactions();
  }

  // --- دوال التحديد ---
  void toggleOrderSelection(int id) { if (selectedOrderIds.contains(id)) selectedOrderIds.remove(id); else selectedOrderIds.add(id); isSelectionMode = selectedOrderIds.isNotEmpty; notifyListeners(); }
  void selectAllOrders() { selectedOrderIds = displayedOrders.map((o) => o['id'] as int).toSet(); isSelectionMode = true; notifyListeners(); }
  void clearSelection() { selectedOrderIds.clear(); isSelectionMode = false; notifyListeners(); }
  void toggleTransactionSelection(int id) { if (selectedTransactionIds.contains(id)) selectedTransactionIds.remove(id); else selectedTransactionIds.add(id); notifyListeners(); }
  void selectAllTransactions() { selectedTransactionIds = displayedTransactions.map((e) => e['id'] as int).toSet(); notifyListeners(); }
  void clearTransactionSelection() { selectedTransactionIds.clear(); notifyListeners(); }

  // --- تصدير الأوردرات للإكسيل ---
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
      double deposit = order['deposit'] ?? 0;
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
        DoubleCellValue(trans['amount'])
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
  // ⚠️⚠️⚠️ حط مفتاحك هنا ⚠️⚠️⚠️
  static const String _apiKey = 'YOUR_API_KEY_HERE';

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