import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  Widget build(BuildContext context) {
    var controller = Provider.of<BusinessController>(context);
    final currencyFormat = NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م');

    // إحصائيات
    int countProcessing = controller.orders.where((o) => o['status'] == 'قيد التجهيز').length;
    int countShipped = controller.orders.where((o) => o['status'] == 'تم الشحن').length;
    int countDelivered = controller.orders.where((o) => o['status'] == 'تم التسليم').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        // ✅ 1. العنوان يتغير حسب التحديد
        title: Text(
          controller.isSelectionMode 
              ? "${controller.selectedOrderIds.length} محدد" 
              : "إدارة الشحنات",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        // ✅ 2. زر الإغلاق عند التحديد
        leading: controller.isSelectionMode
            ? IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => controller.clearSelection())
            : null,
        
        actions: [
          // --- أزرار وضع التحديد ---
          if (controller.isSelectionMode) ...[
             // ✅ زرار تحديد الكل
             IconButton(
              tooltip: "تحديد الكل",
              icon: const Icon(Icons.select_all, color: Colors.white),
              onPressed: () {
                // تفعيل تحديد الكل من الكنترولر (تأكد انك ضفت الدالة هناك)
                // أو نستخدم اللوجيك المباشر هنا:
                if(controller.displayedOrders.isNotEmpty){
                   controller.selectedOrderIds = controller.displayedOrders.map((o) => o['id'] as int).toSet();
                   // نقوم بعمل تحديث للشاشة
                   setState(() {}); 
                }
              },
            ),

             // ✅ زرار تصدير إكسيل
             IconButton(
              tooltip: "تصدير Excel",
              icon: const Icon(Icons.table_view, color: Colors.greenAccent),
              onPressed: () => controller.exportSelectedToExcel(),
            ),
            
            // ✅ زرار معاينة PDF للمحدد
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
          
          // --- أزرار الوضع العادي ---
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
      
      // ✅ استخدام ConstrainedBox للتجاوب مع الشاشات الكبيرة
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
                padding: const EdgeInsets.only(bottom: 25, left: 15, right: 15, top: 10),
                child: Row(
                  children: [
                    Expanded(child: _statusCard("قيد التجهيز", countProcessing, Colors.orange, 'قيد التجهيز', controller)),
                    const SizedBox(width: 8),
                    Expanded(child: _statusCard("تم الشحن", countShipped, Colors.lightBlueAccent, 'تم الشحن', controller)),
                    const SizedBox(width: 8),
                    Expanded(child: _statusCard("تم التسليم", countDelivered, Colors.lightGreenAccent, 'تم التسليم', controller)),
                  ],
                ),
              ),

              // 2. Search
              Transform.translate(
                offset: const Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: "بحث...",
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isNotEmpty 
                          ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                              _searchCtrl.clear();
                              controller.filterOrders(query: '', status: _activeStatus);
                            }) 
                          : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                      onChanged: (val) => controller.filterOrders(query: val, status: _activeStatus),
                    ),
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
                          return _buildOrderCard(order, currencyFormat, controller);
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

  // --- كروت الحالة ---
  Widget _statusCard(String title, int count, Color color, String filterKey, BusinessController ctrl) {
    bool isActive = _activeStatus == filterKey;
    return InkWell(
      onTap: () {
        setState(() => _activeStatus = (_activeStatus == filterKey) ? 'All' : filterKey);
        ctrl.filterOrders(query: _searchCtrl.text, status: _activeStatus);
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
  Widget _buildOrderCard(Map order, NumberFormat cf, BusinessController ctrl) {
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
      color: isSelected ? const Color(0xFF1A237E).withOpacity(0.05) : Colors.white,
      child: ExpansionTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (val) => ctrl.toggleOrderSelection(order['id']),
          activeColor: const Color(0xFF1A237E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        title: Text(order['client_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text("📱 ${order['client_phone']} \n📍 ${order['client_gov'] ?? ''} - ${order['client_region'] ?? ''}", style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 13)),
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
                // تفاصيل المنتجات والملاحظات
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
                       if(order['shipping_company'] != null && order['shipping_company'] != '')
                        Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text("🚚 شركة: ${order['shipping_company']}", style: const TextStyle(color: Colors.blueGrey)),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text("🏠 ${order['client_address']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                
                // الحسابات المالية
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
                    // زرار تحصيل الباقي
                    if (remaining > 0)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.attach_money, size: 18, color: Colors.white),
                        label: const Text("تحصيل", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        onPressed: () => _showCollectRemainingDialog(context, order, remaining, ctrl),
                      ),
                      
                    // زر التعديل
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 18, color: Colors.orange),
                      label: const Text("تعديل"),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () => _showOrderDialog(context, order),
                    ),

                    // زر تغيير الحالة
                    Container(
                      height: 35,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: ['قيد التجهيز', 'تم الشحن', 'تم التسليم'].contains(order['status']) ? order['status'] : 'قيد التجهيز',
                          icon: const Icon(Icons.arrow_drop_down),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          items: ['قيد التجهيز', 'تم الشحن', 'تم التسليم'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) => ctrl.updateOrderStatus(order['id'], val!),
                        ),
                      ),
                    ),

                    // زر المعاينة الفردية
                    IconButton(
                      tooltip: "معاينة البوليصة",
                      icon: const Icon(Icons.visibility, color: Colors.blue), 
                      onPressed: () => _showPdfPreview(context, [order as Map<String, dynamic>])
                    ),

                    // زر الحذف (يظهر هنا)
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

  // --- دوال مساعدة ---
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

  // --- ديالوج الإضافة والتعديل (Responsive) ---
  void _showOrderDialog(BuildContext context, Map? orderToEdit) {
    bool isEdit = orderToEdit != null;
    final nameCtrl = TextEditingController(text: isEdit ? orderToEdit['client_name'] : "");
    final phoneCtrl = TextEditingController(text: isEdit ? orderToEdit['client_phone'] : "");
    final addrCtrl = TextEditingController(text: isEdit ? orderToEdit['client_address'] : "");
    final govCtrl = TextEditingController(text: isEdit ? orderToEdit['client_gov'] : "");
    final regionCtrl = TextEditingController(text: isEdit ? orderToEdit['client_region'] : "");
    final shippingCompCtrl = TextEditingController(text: isEdit ? orderToEdit['shipping_company'] : "");
    final detailsCtrl = TextEditingController(text: isEdit ? orderToEdit['details'] : "");
    final notesCtrl = TextEditingController(text: isEdit ? orderToEdit['notes'] : "");
    final priceCtrl = TextEditingController(text: isEdit ? orderToEdit['total_price'].toString() : "");
    final shippingCtrl = TextEditingController(text: isEdit ? orderToEdit['shipping_cost'].toString() : "0");
    final depositCtrl = TextEditingController(text: isEdit ? orderToEdit['deposit'].toString() : "0");
    
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        double screenWidth = MediaQuery.of(context).size.width;

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          title: Row(
            children: [
              Icon(isEdit ? Icons.edit_note : Icons.add_shopping_cart, color: const Color(0xFF1A237E)),
              const SizedBox(width: 10),
              Text(isEdit ? "تعديل الأوردر" : "أوردر جديد", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                     Container(
                       padding: const EdgeInsets.all(10),
                       decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                       child: Column(
                         children: [
                           const Text("👤 بيانات العميل", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                           const SizedBox(height: 10),
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
                         ],
                       ),
                     ),
                     const SizedBox(height: 15),
                     Container(
                       padding: const EdgeInsets.all(10),
                       decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
                       child: Column(
                         children: [
                           const Text("📦 تفاصيل الشحنة", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                           const SizedBox(height: 10),
                           _buildTextField(shippingCompCtrl, "شركة الشحن (داخلي)", Icons.local_shipping, false),
                           const SizedBox(height: 10),
                           _buildTextField(detailsCtrl, "المنتجات", Icons.shopping_bag, true, maxLines: 3),
                           const SizedBox(height: 10),
                           _buildTextField(notesCtrl, "ملاحظات", Icons.note, false),
                         ],
                       ),
                     ),
                     const SizedBox(height: 15),
                     Container(
                       padding: const EdgeInsets.all(10),
                       decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade100)),
                       child: Column(
                         children: [
                           const Text("💰 الحسابات", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                           const SizedBox(height: 10),
                           Row(children: [
                             Expanded(child: _buildTextField(priceCtrl, "السعر", Icons.attach_money, true, isNumber: true)),
                             const SizedBox(width: 8),
                             Expanded(child: _buildTextField(shippingCtrl, "الشحن", Icons.local_shipping, false, isNumber: true)),
                           ]),
                           const SizedBox(height: 10),
                           _buildTextField(depositCtrl, "العربون المدفوع", Icons.monetization_on, false, isNumber: true),
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
                    child: const Text("إلغاء", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final ctrl = Provider.of<BusinessController>(context, listen: false);
                        if (isEdit) {
                          await ctrl.updateOrder(
                            orderToEdit['id'],
                            nameCtrl.text, phoneCtrl.text, addrCtrl.text,
                            govCtrl.text, regionCtrl.text,
                            detailsCtrl.text, notesCtrl.text,
                            double.parse(priceCtrl.text),
                            double.tryParse(shippingCtrl.text) ?? 0,
                            double.tryParse(depositCtrl.text) ?? 0,
                            shippingCompCtrl.text
                          );
                        } else {
                          await ctrl.addOrder(
                            nameCtrl.text, phoneCtrl.text, addrCtrl.text,
                            govCtrl.text, regionCtrl.text,
                            detailsCtrl.text, notesCtrl.text,
                            double.parse(priceCtrl.text), 
                            double.tryParse(shippingCtrl.text) ?? 0.0,
                            double.tryParse(depositCtrl.text) ?? 0.0,
                            shippingCompCtrl.text
                          );
                        }
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: Text(isEdit ? "حفظ التعديلات" : "إضافة", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
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