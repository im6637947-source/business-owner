import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // عشان الـ Clipboard
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart'; 
import '../controllers/business_controller.dart';
import '../pdf_helper.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _activeStatus = 'All';
  DateTime? _filterDate;
  String? _selectedCompanyFilter; // 🚚 متغير لفلتر الشركة

  @override
  Widget build(BuildContext context) {
    var controller = Provider.of<BusinessController>(context);
    final currencyFormat = NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م');
    
    // تجهيز قائمة الفلتر
    List<String> companyFilterList = ['الكل', ...controller.shippingCompanies.map((e) => e['name'].toString())];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        title: Text(
          controller.isSelectionMode 
              ? "${controller.selectedOrderIds.length} محدد" 
              : "إدارة الشحنات",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: controller.isSelectionMode
            ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => controller.clearSelection())
            : null,
        
        actions: [
          // زرار إدارة الشركات (يظهر فقط في الوضع العادي)
          if (!controller.isSelectionMode)
             IconButton(
               tooltip: "إدارة شركات الشحن",
               icon: const Icon(Icons.business, color: Colors.white),
               onPressed: () => Navigator.pushNamed(context, '/shipping'),
             ),

          if (controller.isSelectionMode) ...[
             IconButton(icon: const Icon(Icons.select_all, color: Colors.white), onPressed: () => controller.selectAllOrders()),
             IconButton(icon: const Icon(Icons.table_view, color: Colors.greenAccent), onPressed: () => controller.exportSelectedToExcel()),
             IconButton(
               tooltip: "معاينة المحدد PDF",
               icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
               onPressed: () {
                 List<Map<String, dynamic>> selectedOrders = controller.orders
                     .where((o) => controller.selectedOrderIds.contains(o['id']))
                     .toList();
                 _showPdfPreview(context, selectedOrders);
                 controller.clearSelection();
               },
             ),
          ],
          
          if (!controller.isSelectionMode)
             IconButton(
               tooltip: "طباعة كل قيد التجهيز",
               icon: const Icon(Icons.print_disabled_outlined, color: Colors.orangeAccent),
               onPressed: () {
                 List<Map<String, dynamic>> pendingOrders = controller.orders
                     .where((o) => o['status'] == 'قيد التجهيز')
                     .toList();
                 if(pendingOrders.isNotEmpty) {
                    _showPdfPreview(context, pendingOrders);
                 } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("مفيش أوردرات قيد التجهيز")));
                 }
               },
             )
        ],
      ),
      
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // 1. Dashboard
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1A237E),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                ),
                padding: const EdgeInsets.only(bottom: 25, left: 5, right: 5, top: 10),
                child: Row(
                  children: [
                    Expanded(child: _statusCard("قيد التجهيز", controller.orders.where((o)=>o['status']=='قيد التجهيز').length, Colors.orange, 'قيد التجهيز', controller)),
                    const SizedBox(width: 4),
                    Expanded(child: _statusCard("تم الشحن", controller.orders.where((o)=>o['status']=='تم الشحن').length, Colors.lightBlueAccent, 'تم الشحن', controller)),
                    const SizedBox(width: 4),
                    Expanded(child: _statusCard("تم التسليم", controller.orders.where((o)=>o['status']=='تم التسليم').length, Colors.lightGreenAccent, 'تم التسليم', controller)),
                  ],
                ),
              ),

              // 2. Search & Filters
              Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    children: [
                      // الصف الأول: بحث + تاريخ
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: InputDecoration(
                                  hintText: "بحث...",
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _searchCtrl.text.isNotEmpty 
                                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _applyFilters(controller); }) 
                                    : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                ),
                                onChanged: (val) => _applyFilters(controller),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Card(
                            elevation: 4,
                            shape: const CircleBorder(),
                            color: _filterDate != null ? const Color(0xFF1A237E) : Colors.white,
                            child: IconButton(
                              tooltip: "فلتر بالتاريخ",
                              icon: Icon(Icons.calendar_month, color: _filterDate != null ? Colors.white : const Color(0xFF1A237E)),
                              onPressed: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: _filterDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setState(() => _filterDate = picked);
                                  _applyFilters(controller);
                                }
                              },
                            ),
                          ),
                          if (_filterDate != null)
                             Padding(
                               padding: const EdgeInsets.only(right: 5),
                               child: CircleAvatar(
                                 backgroundColor: Colors.red,
                                 radius: 18,
                                 child: IconButton(
                                   icon: const Icon(Icons.close, size: 18, color: Colors.white),
                                   onPressed: () { setState(() => _filterDate = null); _applyFilters(controller); },
                                 ),
                               ),
                             )
                        ],
                      ),
                      
                      // الصف الثاني: فلتر شركات الشحن
                      const SizedBox(height: 5),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text("تصفية بالشركة: ", style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade300)
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedCompanyFilter ?? 'الكل',
                                  items: companyFilterList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedCompanyFilter = val);
                                    _applyFilters(controller);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),

              // 3. List
              Expanded(
                child: controller.displayedOrders.isEmpty
                    ? const Center(child: Text("لا توجد شحنات"))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 80),
                        itemCount: controller.displayedOrders.length,
                        itemBuilder: (context, index) {
                          final order = controller.displayedOrders[index];
                          // 🚨 كشف التأخير
                          bool isLate = controller.isOrderLate(order);
                          
                          return _buildOrderCard(order, currencyFormat, controller, isLate);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      
      floatingActionButton: controller.isSelectionMode 
        ? null 
        : FloatingActionButton.extended(
            onPressed: () => _showOrderDialog(context, null),
            backgroundColor: const Color(0xFF1A237E),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("أوردر جديد", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
    );
  }

  void _applyFilters(BusinessController controller) {
    String? dateStr = _filterDate != null ? DateFormat('yyyy-MM-dd').format(_filterDate!) : null;
    controller.filterOrders(
      query: _searchCtrl.text,
      status: _activeStatus,
      date: dateStr,
      company: _selectedCompanyFilter
    );
  }

  // --- كروت الحالة ---
  Widget _statusCard(String title, int count, Color color, String filterKey, BusinessController ctrl) {
    bool isActive = _activeStatus == filterKey;
    return InkWell(
      onTap: () {
        setState(() => _activeStatus = (_activeStatus == filterKey) ? 'All' : filterKey);
        _applyFilters(ctrl);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive ? Border.all(color: Colors.white, width: 1) : Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text("$count", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // --- كارت الأوردر ---
  Widget _buildOrderCard(Map order, NumberFormat cf, BusinessController ctrl, bool isLate) {
    bool isSelected = ctrl.selectedOrderIds.contains(order['id']);
    double total = order['total_price'] + (order['shipping_cost'] ?? 0);
    double remaining = total - order['deposit'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: isSelected ? const BorderSide(color: Color(0xFF1A237E), width: 2) : BorderSide.none,
      ),
      // 🚨 لون خلفية أحمر خفيف لو متأخر
      color: isLate ? Colors.red.shade50 : (isSelected ? const Color(0xFF1A237E).withOpacity(0.05) : Colors.white),
      child: ExpansionTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (val) => ctrl.toggleOrderSelection(order['id']),
          activeColor: const Color(0xFF1A237E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(order['client_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if(isLate) // ⚠️ أيقونة تحذير
                  const Padding(padding: EdgeInsets.only(right: 5), child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20)),
              ],
            ),
            Text(order['date'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📱 ${order['client_phone']} \n📍 ${order['client_gov'] ?? ''} - ${order['client_region'] ?? ''}", style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 13)),
            // عرض شركة الشحن في الكارت
            if(order['shipping_company'] != null && order['shipping_company'] != '')
              Text("🚚 شركة: ${order['shipping_company']}", style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
            
            if(isLate)
              const Text("⚠️ متأخرة (أكثر من 3 أيام)", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(order['status']).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _getStatusColor(order['status'])),
          ),
          child: Text(
            order['status'],
            style: TextStyle(fontSize: 11, color: _getStatusColor(order['status']), fontWeight: FontWeight.bold),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                // تفاصيل
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row("📦 المنتجات:", order['details'], isBold: true),
                        if(order['notes'] != null && order['notes'] != '')
                         Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Text("📝 ${order['notes']}", style: const TextStyle(color: Colors.redAccent)),
                         ),
                         Padding(
                           padding: const EdgeInsets.only(top: 5.0),
                           child: Text("🏠 ${order['client_address']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                         ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                // الحسابات
                _row("سعر المنتجات:", cf.format(order['total_price'])),
                _row("الشحن:", "+ ${cf.format(order['shipping_cost'] ?? 0)}"),
                _row("العربون المدفوع:", "- ${cf.format(order['deposit'])}", color: Colors.green),
                const Divider(thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("المبلغ المتبقي:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(cf.format(remaining), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: remaining > 0 ? Colors.red : Colors.green)),
                  ],
                ),
                const SizedBox(height: 20),
                // أزرار التحكم
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    if (remaining > 0)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.attach_money, size: 18, color: Colors.white),
                        label: const Text("تحصيل", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        onPressed: () => _showCollectRemainingDialog(context, order, remaining, ctrl),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 18, color: Colors.orange),
                      label: const Text("تعديل"),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () => _showOrderDialog(context, order),
                    ),
                    // زرار تغيير الحالة السريع
                    DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: ['قيد التجهيز', 'تم الشحن', 'تم التسليم'].contains(order['status']) ? order['status'] : 'قيد التجهيز',
                          icon: const Icon(Icons.arrow_drop_down),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                          items: ['قيد التجهيز', 'تم الشحن', 'تم التسليم'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) => ctrl.updateOrderStatus(order['id'], val!),
                        ),
                      ),
                    IconButton(
                      tooltip: "حذف",
                      icon: const Icon(Icons.delete, color: Colors.red), 
                      onPressed: () => _confirmDelete(context, ctrl, order['id'])
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'تم الشحن') return Colors.blue;
    if (status == 'تم التسليم') return Colors.green;
    return Colors.orange;
  }

  Widget _row(String label, String val, {Color color = Colors.black87, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)), 
          Expanded(child: Text(val, textAlign: TextAlign.end, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)))
        ],
      ),
    );
  }

  // 📅 --- ديالوج الإضافة والتعديل مع الذكاء الاصطناعي وشركات الشحن ---
  void _showOrderDialog(BuildContext context, Map? orderToEdit) {
    bool isEdit = orderToEdit != null;
    final nameCtrl = TextEditingController(text: isEdit ? orderToEdit['client_name'] : "");
    final phoneCtrl = TextEditingController(text: isEdit ? orderToEdit['client_phone'] : "");
    final addrCtrl = TextEditingController(text: isEdit ? orderToEdit['client_address'] : "");
    final govCtrl = TextEditingController(text: isEdit ? orderToEdit['client_gov'] : "");
    final regionCtrl = TextEditingController(text: isEdit ? orderToEdit['client_region'] : "");
    final detailsCtrl = TextEditingController(text: isEdit ? orderToEdit['details'] : "");
    final notesCtrl = TextEditingController(text: isEdit ? orderToEdit['notes'] : "");
    final priceCtrl = TextEditingController(text: isEdit ? orderToEdit['total_price'].toString() : "");
    final shippingCtrl = TextEditingController(text: isEdit ? orderToEdit['shipping_cost'].toString() : "0");
    final depositCtrl = TextEditingController(text: isEdit ? orderToEdit['deposit'].toString() : "0");
    
    // متغير لشركة الشحن
    String? selectedCompany = isEdit ? orderToEdit['shipping_company'] : null;
    final ctrl = Provider.of<BusinessController>(context, listen: false);
    
    // افتراضي أول شركة لو مفيش
    if (selectedCompany == null && ctrl.shippingCompanies.isNotEmpty) {
      selectedCompany = ctrl.shippingCompanies.first['name'];
    }

    // 📅 التاريخ
    DateTime selectedDate = isEdit 
        ? (DateTime.tryParse(orderToEdit['date'] ?? '') ?? DateTime.now()) 
        : DateTime.now();

    final formKey = GlobalKey<FormState>();
    bool isAnalyzing = false; // حالة التحميل للذكاء الاصطناعي

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        double screenWidth = MediaQuery.of(context).size.width;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            // 🔥 دالة النسخ الذكي
            Future<void> handleSmartPaste() async {
              ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data != null && data.text != null && data.text!.isNotEmpty) {
                setStateDialog(() => isAnalyzing = true);
                
                // استدعاء الكنترولر للتحليل
                var result = await ctrl.analyzeOrderText(data.text!);
                
                setStateDialog(() => isAnalyzing = false);

                if (result != null) {
                  nameCtrl.text = result['name'] ?? "";
                  phoneCtrl.text = result['phone'] ?? "";
                  priceCtrl.text = result['price']?.toString() ?? "";
                  addrCtrl.text = result['address'] ?? "";
                  govCtrl.text = result['gov'] ?? "";
                  regionCtrl.text = result['region'] ?? "";
                  detailsCtrl.text = result['details'] ?? "";
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✨ تم استخراج البيانات!"), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل التحليل، تأكد من النت"), backgroundColor: Colors.red));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الحافظة فارغة! انسخ النص أولاً")));
              }
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(isEdit ? Icons.edit_note : Icons.add_shopping_cart, color: const Color(0xFF1A237E)),
                      const SizedBox(width: 10),
                      Text(isEdit ? "تعديل" : "جديد", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  // ✨ زرار النسخ الذكي
                  if (!isEdit)
                    ElevatedButton.icon(
                      onPressed: isAnalyzing ? null : handleSmartPaste,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade50, foregroundColor: Colors.purple, elevation: 0),
                      icon: isAnalyzing 
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) 
                        : const Icon(Icons.auto_awesome, size: 18),
                      label: const Text("Smart Paste"),
                    )
                ],
              ),
              content: SizedBox(
                width: screenWidth > 600 ? 500 : screenWidth,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 📅 التاريخ
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                               const Padding(padding: EdgeInsets.only(right: 8), child: Text("📅 التاريخ:", style: TextStyle(fontWeight: FontWeight.bold))),
                               TextButton(
                                 child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                                 onPressed: () async {
                                   DateTime? picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                                   if (picked != null) setStateDialog(() => selectedDate = picked);
                                 },
                               )
                            ],
                          ),
                        ),

                        // البيانات
                        _buildTextField(nameCtrl, "اسم العميل", Icons.person, true),
                        const SizedBox(height: 10),
                        _buildTextField(phoneCtrl, "الموبايل", Icons.phone, true, isNumber: true),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _buildTextField(govCtrl, "المحافظة", Icons.map, false)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildTextField(regionCtrl, "المنطقة", Icons.location_city, false)),
                        ]),
                        const SizedBox(height: 10),
                        _buildTextField(addrCtrl, "العنوان بالتفصيل", Icons.home, false),
                        
                        const SizedBox(height: 15),
                        // 🚚 دروب داون شركات الشحن
                        if (ctrl.shippingCompanies.isNotEmpty)
                          DropdownButtonFormField<String>(
                            value: selectedCompany,
                            decoration: InputDecoration(
                              labelText: "شركة الشحن", 
                              prefixIcon: const Icon(Icons.local_shipping, color: Color(0xFF1A237E)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true, fillColor: Colors.white
                            ),
                            items: ctrl.shippingCompanies.map((c) {
                              return DropdownMenuItem<String>(value: c['name'], child: Text(c['name']));
                            }).toList(),
                            onChanged: (val) => setStateDialog(() => selectedCompany = val),
                          )
                        else
                          InkWell(
                            onTap: () => Navigator.pushNamed(context, '/shipping'), // الذهاب لإضافة شركة
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(border: Border.all(color: Colors.red), borderRadius: BorderRadius.circular(10)),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 5), Text("أضف شركة شحن أولاً", style: TextStyle(color: Colors.red))],
                              ),
                            ),
                          ),

                        const SizedBox(height: 10),
                        _buildTextField(detailsCtrl, "المنتجات", Icons.shopping_bag, true, maxLines: 3),
                        const SizedBox(height: 10),
                        _buildTextField(notesCtrl, "ملاحظات", Icons.note, false),
                        
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            children: [
                              Row(children: [
                                Expanded(child: _buildTextField(priceCtrl, "السعر", Icons.attach_money, true, isNumber: true)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildTextField(shippingCtrl, "الشحن", Icons.local_shipping, false, isNumber: true)),
                              ]),
                              const SizedBox(height: 10),
                              _buildTextField(depositCtrl, "العربون", Icons.monetization_on, false, isNumber: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context), 
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Colors.red)),
                        child: const Text("إلغاء", style: TextStyle(color: Colors.red))
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            // تحويل التاريخ لنص
                            String dateString = DateFormat('yyyy-MM-dd').format(selectedDate);

                            if (isEdit) {
                              await ctrl.updateOrder(
                                orderToEdit['id'],
                                nameCtrl.text, phoneCtrl.text, addrCtrl.text,
                                govCtrl.text, regionCtrl.text,
                                detailsCtrl.text, notesCtrl.text,
                                double.parse(priceCtrl.text),
                                double.tryParse(shippingCtrl.text) ?? 0,
                                double.tryParse(depositCtrl.text) ?? 0,
                                selectedCompany ?? '', // الشركة المختارة
                                date: dateString
                              );
                            } else {
                              await ctrl.addOrder(
                                nameCtrl.text, phoneCtrl.text, addrCtrl.text,
                                govCtrl.text, regionCtrl.text,
                                detailsCtrl.text, notesCtrl.text,
                                double.parse(priceCtrl.text), 
                                double.tryParse(shippingCtrl.text) ?? 0.0,
                                double.tryParse(depositCtrl.text) ?? 0.0,
                                selectedCompany ?? '', // الشركة المختارة
                                date: dateString
                              );
                            }
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                        child: Text(isEdit ? "حفظ" : "إضافة", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildTextField(TextEditingController c, String label, IconData icon, bool required, {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : [],
      validator: required ? (v) => v!.isEmpty ? "مطلوب" : null : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF1A237E).withOpacity(0.7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        isDense: true,
        filled: true,
        fillColor: Colors.white
      ),
    );
  }
  
  void _showPdfPreview(BuildContext context, List<Map<String, dynamic>> orders) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
      appBar: AppBar(title: const Text("معاينة البوليصة")),
      body: PdfPreview(
        build: (format) => PdfHelper.generateBulkOrdersBytes(orders), 
      ),
    )));
  }

  void _showCollectRemainingDialog(BuildContext context, Map order, double currentRemaining, BusinessController ctrl) {
     final amountCtrl = TextEditingController(text: currentRemaining.toString());
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text("تحصيل باقي المبلغ"),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Text("المبلغ المتبقي حالياً: $currentRemaining"),
             const SizedBox(height: 10),
             TextField(
               controller: amountCtrl,
               keyboardType: TextInputType.number,
               decoration: const InputDecoration(labelText: "المبلغ المدفوع الآن", border: OutlineInputBorder()),
             )
           ],
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
             onPressed: () {
                double newPayment = double.tryParse(amountCtrl.text) ?? 0;
                double oldDeposit = order['deposit'] ?? 0;
                ctrl.updateOrderDeposit(order['id'], oldDeposit + newPayment);
                Navigator.pop(ctx);
             },
             child: const Text("تأكيد الدفع", style: TextStyle(color: Colors.white)),
           )
         ],
       ),
     );
  }

  void _confirmDelete(BuildContext context, BusinessController ctrl, int id) {
     showDialog(context: context, builder: (ctx) => AlertDialog(
       title: const Text("تأكيد الحذف"),
       content: const Text("هل أنت متأكد من حذف هذا الأوردر؟"),
       actions: [
         TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
         TextButton(onPressed: () { ctrl.deleteOrder(id); Navigator.pop(ctx); }, child: const Text("حذف", style: TextStyle(color: Colors.red))),
       ],
     ));
  }
}