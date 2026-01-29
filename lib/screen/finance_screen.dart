import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../controllers/business_controller.dart';
import '../pdf_helper.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  bool _isSelectionModeActive = false;
  DateTime? _filterDate; // 📅 متغير لحفظ التاريخ المختار

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م');
    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a', 'en');
    final filterDateFormat = DateFormat('yyyy-MM-dd');

    return Consumer<BusinessController>(
      builder: (context, controller, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF0F2F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A237E),
            elevation: 0,
            
            title: Text(
              _isSelectionModeActive
                  ? "${controller.selectedTransactionIds.length} محدد"
                  : "الخزنة والإدارة",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
            ),

            leading: _isSelectionModeActive
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _isSelectionModeActive = false;
                        controller.clearTransactionSelection();
                      });
                    })
                : null,

            actions: [
              // --- أزرار وضع التحديد ---
              if (_isSelectionModeActive) ...[
                IconButton(
                  tooltip: "تحديد الكل",
                  icon: const Icon(Icons.select_all, color: Colors.white),
                  onPressed: () => controller.selectAllTransactions(),
                ),
                IconButton(
                  tooltip: "تصدير Excel",
                  icon: const Icon(Icons.table_view, color: Colors.greenAccent),
                  onPressed: () {
                    controller.exportTransactionsToExcel();
                    setState(() => _isSelectionModeActive = false);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.print, color: Colors.white),
                  tooltip: "طباعة المحدد",
                  onPressed: () {
                    if (controller.selectedTransactionIds.isNotEmpty) {
                      List<Map<String, dynamic>> selectedList = controller.displayedTransactions
                          .where((t) => controller.selectedTransactionIds.contains(t['id']))
                          .toList();
                      _showPdfPreview(context, selectedList, controller.totalBalance);
                      setState(() {
                        _isSelectionModeActive = false;
                        controller.clearTransactionSelection();
                      });
                    }
                  },
                ),
              ] 
              // --- أزرار الوضع العادي ---
              else ...[
                IconButton(
                  tooltip: "تحديد عناصر",
                  icon: const Icon(Icons.checklist_rtl, color: Colors.white),
                  onPressed: () => setState(() => _isSelectionModeActive = true),
                ),
                IconButton(
                  icon: const Icon(Icons.print, color: Colors.white),
                  tooltip: "طباعة التقرير",
                  onPressed: () {
                    if (controller.displayedTransactions.isNotEmpty) {
                      _showPdfPreview(context, controller.displayedTransactions, controller.totalBalance);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا توجد بيانات للطباعة")));
                    }
                  },
                ),
              ],
            ],
          ),
          
          body: Column(
            children: [
              // 1. ملخص الرصيد (Dashboard)
              if (!_isSelectionModeActive)
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: Column(
                  children: [
                    const Text("صافي الرصيد الحالي", style: TextStyle(color: Colors.grey)),
                    Text(
                      currencyFormat.format(controller.totalBalance),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: controller.totalBalance >= 0 ? const Color(0xFF1A237E) : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(child: _statCard("إيرادات", controller.totalIncome, Colors.green)),
                        const SizedBox(width: 10),
                        Expanded(child: _statCard("مصروفات", controller.totalExpense, Colors.red)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 5),

              // 2. شريط الفلاتر والتاريخ
              if (!_isSelectionModeActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    _buildFilterButton(controller, "الكل", "all"),
                    const SizedBox(width: 5),
                    _buildFilterButton(controller, "وارد", "income", activeColor: Colors.green),
                    const SizedBox(width: 5),
                    _buildFilterButton(controller, "صادر", "expense", activeColor: Colors.red),
                    
                    const Spacer(), 

                    // 📅 زرار التاريخ
                    Container(
                      decoration: BoxDecoration(
                        color: _filterDate != null ? const Color(0xFF1A237E) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade400)
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.calendar_month, size: 20, color: _filterDate != null ? Colors.white : Colors.grey[700]),
                            onPressed: () async {
                              DateTime? picked = await showDatePicker(
                                context: context, 
                                initialDate: _filterDate ?? DateTime.now(), 
                                firstDate: DateTime(2020), 
                                lastDate: DateTime(2030)
                              );
                              if (picked != null) {
                                setState(() => _filterDate = picked);
                                controller.filterTransactions(
                                  type: controller.currentFilter, 
                                  date: filterDateFormat.format(picked)
                                );
                              }
                            },
                          ),
                          if (_filterDate != null)
                            IconButton(
                              constraints: const BoxConstraints(minWidth: 30, minHeight: 36),
                              padding: const EdgeInsets.only(right: 8),
                              icon: const Icon(Icons.close, size: 18, color: Colors.white),
                              onPressed: () {
                                setState(() => _filterDate = null);
                                controller.filterTransactions(type: controller.currentFilter, date: null);
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (!_isSelectionModeActive) const Divider(height: 1),

              // 3. القائمة (Transactions List) مع ميزة السحب للتحديث (Pull to Refresh)
              Expanded(
                child: controller.displayedTransactions.isEmpty
                    ? const Center(child: Text("مفيش حركات مسجلة", style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator( // ✅ ميزة جديدة: اسحب الشاشة لتحت عشان تعمل ريفرش
                        onRefresh: () async {
                          await controller.fetchTransactions();
                        },
                        child: ListView.builder(
                          itemCount: controller.displayedTransactions.length,
                          padding: const EdgeInsets.only(bottom: 80),
                          itemBuilder: (context, index) {
                            final trans = controller.displayedTransactions[index];
                            bool isIncome = trans['isIncome'] == 1;
                            bool isSelected = controller.selectedTransactionIds.contains(trans['id']);

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              color: isSelected ? const Color(0xFF1A237E).withOpacity(0.1) : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: isSelected ? const BorderSide(color: Color(0xFF1A237E), width: 2) : BorderSide.none,
                              ),
                              child: ListTile(
                                leading: _isSelectionModeActive
                                    ? Checkbox(
                                        value: isSelected,
                                        activeColor: const Color(0xFF1A237E),
                                        onChanged: (val) => controller.toggleTransactionSelection(trans['id']),
                                      )
                                    : CircleAvatar(
                                        backgroundColor: isIncome ? Colors.green.shade50 : Colors.red.shade50,
                                        child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                            color: isIncome ? Colors.green : Colors.red),
                                      ),
                                title: Text(trans['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(dateFormat.format(DateTime.parse(trans['date']))),
                                trailing: Text(
                                  currencyFormat.format(trans['amount']),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.red),
                                ),
                                onTap: () {
                                  if (_isSelectionModeActive) {
                                    controller.toggleTransactionSelection(trans['id']);
                                  } else {
                                    _openAddDialog(context, existingData: trans);
                                  }
                                },
                                onLongPress: () {
                                  if (!_isSelectionModeActive) {
                                    _confirmDelete(context, controller, trans['id']);
                                  } else {
                                    controller.toggleTransactionSelection(trans['id']);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
          
          floatingActionButton: _isSelectionModeActive 
            ? null 
            : FloatingActionButton(
                onPressed: () => _openAddDialog(context),
                backgroundColor: const Color(0xFF1A237E),
                child: const Icon(Icons.add, color: Colors.white),
              ),
        );
      },
    );
  }

  // --- Widgets ---

  Widget _buildFilterButton(BusinessController ctrl, String text, String filterValue, {Color activeColor = const Color(0xFF1A237E)}) {
    bool isSelected = ctrl.currentFilter == filterValue;
    return GestureDetector(
      onTap: () {
        String? dateStr = _filterDate != null ? DateFormat('yyyy-MM-dd').format(_filterDate!) : null;
        ctrl.filterTransactions(type: filterValue, date: dateStr);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? activeColor : Colors.grey.shade300),
          boxShadow: isSelected ? [BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, double val, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [Text(title, style: TextStyle(color: color)), Text(val.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16))]),
    );
  }

  // --- Dialogs & Functions ---

  void _openAddDialog(BuildContext context, {Map? existingData}) {
    final titleCtrl = TextEditingController(text: existingData?['title']);
    final amountCtrl = TextEditingController(text: existingData?['amount']?.toString());
    bool isIncome = existingData != null ? (existingData['isIncome'] == 1) : false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(existingData == null ? "حركة جديدة" : "تعديل", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: InkWell(onTap: () => setDialogState(() => isIncome = false), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: !isIncome ? Colors.red : Colors.grey[200], borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: Text("مصروف (خارج)", style: TextStyle(color: !isIncome ? Colors.white : Colors.black, fontWeight: FontWeight.bold))))),
                  const SizedBox(width: 10),
                  Expanded(child: InkWell(onTap: () => setDialogState(() => isIncome = true), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isIncome ? Colors.green : Colors.grey[200], borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: Text("إيراد (داخل)", style: TextStyle(color: isIncome ? Colors.white : Colors.black, fontWeight: FontWeight.bold))))),
                ],
              ),
              const SizedBox(height: 15),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "الوصف", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "المبلغ", border: OutlineInputBorder())),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, 
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), padding: const EdgeInsets.all(15)),
                  onPressed: () async {
                    if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                    
                    final ctrl = Provider.of<BusinessController>(context, listen: false);
                    if (existingData == null) {
                      await ctrl.addTransaction(titleCtrl.text, double.parse(amountCtrl.text), isIncome);
                    } else {
                      await ctrl.updateTransaction(existingData['id'], titleCtrl.text, double.parse(amountCtrl.text), isIncome);
                    }
                    Navigator.pop(context);
                  }, 
                  child: const Text("حفظ", style: TextStyle(color: Colors.white, fontSize: 16))
                )
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showPdfPreview(BuildContext context, List<Map<String, dynamic>> transactions, double balance) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
      appBar: AppBar(title: const Text("معاينة التقرير المالي")),
      body: PdfPreview(
        build: (format) => PdfHelper.generateFinanceReportBytes(transactions, balance),
      ),
    )));
  }

  void _confirmDelete(BuildContext context, BusinessController ctrl, int id) {
     showDialog(context: context, builder: (ctx) => AlertDialog(
       title: const Text("حذف"),
       content: const Text("هل تريد حذف هذه الحركة؟"),
       actions: [
         TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
         TextButton(onPressed: () { ctrl.deleteTransaction(id); Navigator.pop(ctx); }, child: const Text("حذف", style: TextStyle(color: Colors.red))),
       ],
     ));
  }
}