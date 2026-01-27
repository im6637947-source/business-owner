import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart'; // مسار الحفظ
import 'package:excel/excel.dart'; // مكتبة الاكسيل
import 'package:open_file/open_file.dart'; // لفتح الملف بعد الحفظ
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class BusinessController with ChangeNotifier {
  Database? _database;
  
  // --- القوائم ---
  List<Map<String, dynamic>> _allTransactions = []; 
  List<Map<String, dynamic>> displayedTransactions = []; 
  List<Map<String, dynamic>> transactions = []; // alias for displayed or all

  List<Map<String, dynamic>> orders = []; 
  List<Map<String, dynamic>> displayedOrders = [];
  List<Map<String, dynamic>> clients = [];

  // --- التحديد للأوردرات (Selection) ---
  Set<int> selectedOrderIds = {}; 
  bool isSelectionMode = false;

  // --- التحديد للحركات المالية (Selection) ---
  Set<int> selectedTransactionIds = {};
  bool get isTransactionSelectionMode => selectedTransactionIds.isNotEmpty;

  String currentFilter = 'all'; 
  double totalBalance = 0.0;
  double totalIncome = 0.0;
  double totalExpense = 0.0;

  Future<void> initDB() async {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      // v10: لضمان إنشاء الجداول بالعواميد الجديدة
      String path = join(await getDatabasesPath(), 'business_pro_v10.db');
      
      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          // جدول المعاملات
          await db.execute('CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, isIncome INTEGER, date TEXT, type TEXT)');
          
          // جدول العملاء
          await db.execute('CREATE TABLE clients(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT, address TEXT, governorate TEXT, region TEXT)');
          
          // جدول الأوردرات
          await db.execute('CREATE TABLE orders(id INTEGER PRIMARY KEY AUTOINCREMENT, client_id INTEGER, details TEXT, notes TEXT, total_price REAL, shipping_cost REAL, deposit REAL, status TEXT, shipping_company TEXT, date TEXT)');
        },
      );
      await fetchData();
    } catch (e) {
      debugPrint("❌ DB Error: $e");
    }
  }

  Future<void> fetchData() async {
    await fetchTransactions();
    await fetchOrders();
    await fetchClients();
  }

  // ================== Transactions (المعاملات المالية) ==================
  Future<void> fetchTransactions() async {
    final db = _database; if (db == null) return;
    _allTransactions = await db.query('transactions', orderBy: 'date DESC');
    
    // حساب الإجماليات
    totalIncome = 0.0;
    totalExpense = 0.0;
    for (var item in _allTransactions) {
      double amt = item['amount'];
      if (item['isIncome'] == 1) totalIncome += amt; else totalExpense += amt;
    }
    totalBalance = totalIncome - totalExpense;
    
    // تحديث القائمة العامة
    transactions = _allTransactions;
    applyFilter(currentFilter);
  }

  void applyFilter(String type) {
    currentFilter = type;
    if (type == 'all') {
      displayedTransactions = List.from(_allTransactions);
    } else if (type == 'income') {
      displayedTransactions = _allTransactions.where((e) => e['isIncome'] == 1).toList();
    } else {
      displayedTransactions = _allTransactions.where((e) => e['isIncome'] == 0).toList();
    }
    notifyListeners();
  }

  Future<bool> addTransaction(String title, double amount, bool isIncome) async {
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
    await _database?.delete('transactions', where: 'id = ?', whereArgs: [id]);
    await fetchTransactions();
  }

  Future<void> updateTransaction(int id, String title, double amount, bool isIncome) async {
      await _database?.update('transactions', {'title': title, 'amount': amount, 'isIncome': isIncome ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
      await fetchTransactions();
  }

  // --- دوال تحديد الحركات المالية ---
  void toggleTransactionSelection(int id) {
    if (selectedTransactionIds.contains(id)) {
      selectedTransactionIds.remove(id);
    } else {
      selectedTransactionIds.add(id);
    }
    notifyListeners();
  }

  // ✅ دالة تحديد الكل للحركات المالية
  void selectAllTransactions() {
    selectedTransactionIds = displayedTransactions.map((e) => e['id'] as int).toSet();
    notifyListeners();
  }

  void clearTransactionSelection() {
    selectedTransactionIds.clear();
    notifyListeners();
  }

  // --- تصدير الحركات المالية للإكسيل ---
  Future<void> exportTransactionsToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Finance'];

    // 1. الهيدر
    sheetObject.appendRow([
      TextCellValue('م'), 
      TextCellValue('التاريخ'), 
      TextCellValue('الوصف'), 
      TextCellValue('نوع الحركة'), 
      TextCellValue('المبلغ')
    ]);

    // 2. تحديد البيانات
    List<Map<String, dynamic>> listToExport = isTransactionSelectionMode
        ? _allTransactions.where((t) => selectedTransactionIds.contains(t['id'])).toList()
        : displayedTransactions;

    // 3. كتابة البيانات
    for (var trans in listToExport) {
      sheetObject.appendRow([
        IntCellValue(trans['id']),
        TextCellValue(trans['date'].toString().split('T')[0]), // التاريخ فقط
        TextCellValue(trans['title']),
        TextCellValue(trans['isIncome'] == 1 ? 'إيراد' : 'مصروف'),
        DoubleCellValue(trans['amount'])
      ]);
    }

    // 4. الحفظ
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

  // ================== Clients (العملاء) ==================
  Future<void> fetchClients() async {
    clients = await _database!.query('clients', orderBy: 'id DESC');
    notifyListeners();
  }
  
  // ================== Orders (الأوردرات) ==================
  Future<void> fetchOrders() async {
    final db = _database; if (db == null) return;
    
    // استعلام مع دمج بيانات العميل
    final List<Map<String, dynamic>> res = await db.rawQuery('''
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
    // تحديث القائمة المعروضة
    filterOrders(query: '', status: 'All'); 
    notifyListeners();
  }

  void filterOrders({String query = '', String status = 'All'}) {
    displayedOrders = orders.where((order) {
      bool statusMatch = (status == 'All') || (order['status'] == status);
      bool queryMatch = order['client_name'].toString().toLowerCase().contains(query.toLowerCase()) || 
                        order['client_phone'].toString().contains(query);
      return statusMatch && queryMatch;
    }).toList();
    notifyListeners();
  }

  // --- دوال تحديد الأوردرات ---
  void toggleOrderSelection(int id) {
    if (selectedOrderIds.contains(id)) {
      selectedOrderIds.remove(id);
    } else {
      selectedOrderIds.add(id);
    }
    isSelectionMode = selectedOrderIds.isNotEmpty;
    notifyListeners();
  }

  // ✅ دالة تحديد الكل للأوردرات
  void selectAllOrders() {
    selectedOrderIds = displayedOrders.map((o) => o['id'] as int).toSet();
    isSelectionMode = true;
    notifyListeners();
  }

  void clearSelection() {
    selectedOrderIds.clear();
    isSelectionMode = false;
    notifyListeners();
  }

  // --- إدارة الأوردرات (إضافة / تعديل / حذف / تحصيل) ---
  Future<void> addOrder(
      String name, String phone, String addr, 
      String gov, String region, 
      String details, String notes, 
      double price, double shippingCost, double deposit,
      String shippingCompany
      ) async {
    
    // 1. إضافة العميل
    int clientId = await _database!.insert('clients', {
      'name': name, 
      'phone': phone, 
      'address': addr,
      'governorate': gov,
      'region': region
    });

    // 2. إضافة الأوردر
    await _database?.insert('orders', {
      'client_id': clientId, 'details': details, 'notes': notes,
      'total_price': price, 
      'shipping_cost': shippingCost, 
      'deposit': deposit,
      'shipping_company': shippingCompany,
      'status': 'قيد التجهيز', 'date': DateTime.now().toIso8601String(),
    });

    if (deposit > 0) {
      await addTransaction('عربون أوردر - $name', deposit, true);
    }
    await fetchData(); 
  }

  Future<void> updateOrderStatus(int id, String newStatus) async {
    await _database?.update('orders', {'status': newStatus}, where: 'id = ?', whereArgs: [id]);
    await fetchOrders(); 
  }
  
  Future<void> deleteOrder(int id) async {
    await _database?.delete('orders', where: 'id = ?', whereArgs: [id]);
    await fetchOrders();
  }

  Future<void> updateOrderDeposit(int orderId, double newTotalDeposit) async {
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

  Future<void> updateOrder(
      int id, String name, String phone, String addr,
      String gov, String region,
      String details, String notes, 
      double price, double ship, double deposit,
      String shippingCompany
      ) async {
    
    var res = await _database!.query('orders', columns: ['client_id'], where: 'id = ?', whereArgs: [id]);
    if (res.isNotEmpty) {
      int clientId = res.first['client_id'] as int;

      await _database?.update('clients', {
        'name': name, 'phone': phone, 'address': addr,
        'governorate': gov, 'region': region
      }, where: 'id = ?', whereArgs: [clientId]);

      await _database?.update('orders', {
        'details': details, 'notes': notes, 'total_price': price,
        'shipping_cost': ship, 'deposit': deposit,
        'shipping_company': shippingCompany
      }, where: 'id = ?', whereArgs: [id]);
    }
    await fetchData();
  }

  // --- تصدير الأوردرات للإكسيل ---
  Future<void> exportSelectedToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Orders'];
    
    // 1. إعداد الهيدر
    sheetObject.appendRow([
      TextCellValue('رقم الأوردر'), 
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

    // 2. تصفية الأوردرات
    List<Map<String, dynamic>> selectedList = orders
        .where((o) => selectedOrderIds.contains(o['id']))
        .toList();
    
    // 3. تعبئة البيانات
    for (var order in selectedList) {
      double total = (order['total_price'] ?? 0) + (order['shipping_cost'] ?? 0);
      double deposit = order['deposit'] ?? 0;
      double remaining = total - deposit;

      sheetObject.appendRow([
        IntCellValue(order['id']),
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

    // 4. الحفظ
    var fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/Orders_${DateTime.now().toString().replaceAll(':', '-')}.xlsx";
      
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
      
      await OpenFile.open(path);
    }
    
    clearSelection();
  }
}