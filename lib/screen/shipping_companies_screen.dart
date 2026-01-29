import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/business_controller.dart';

class ShippingCompaniesScreen extends StatelessWidget {
  const ShippingCompaniesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // استخدمنا Consumer عشان نضمن تحديث الليست أول ما تتغير
    return Consumer<BusinessController>(
      builder: (context, controller, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF0F2F5), // نفس خلفية باقي التطبيق
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A237E),
            title: const Text("إدارة شركات الشحن", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: controller.shippingCompanies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      const Text("لم تتم إضافة شركات شحن بعد", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: controller.shippingCompanies.length,
                  itemBuilder: (context, index) {
                    var company = controller.shippingCompanies[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF1A237E),
                          child: Icon(Icons.local_shipping, color: Colors.white),
                        ),
                        title: Text(company['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(company['phone'] ?? 'لا يوجد هاتف'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          // ✅ استدعاء دالة التأكيد قبل الحذف
                          onPressed: () => _confirmDelete(context, controller, company['id']),
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddDialog(context),
            backgroundColor: const Color(0xFF1A237E),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  // ✅ ديالوج الإضافة (محسن)
  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("إضافة شركة جديدة"),
        content: SingleChildScrollView( // عشان الكيبورد
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl, 
                decoration: const InputDecoration(labelText: "اسم الشركة", border: OutlineInputBorder())
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl, 
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "رقم الهاتف (اختياري)", border: OutlineInputBorder())
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E)),
            onPressed: () {
              if(nameCtrl.text.trim().isNotEmpty) {
                Provider.of<BusinessController>(context, listen: false)
                    .addShippingCompany(nameCtrl.text.trim(), phoneCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text("إضافة", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // ✅ ديالوج تأكيد الحذف (جديد)
  void _confirmDelete(BuildContext context, BusinessController ctrl, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف الشركة"),
        content: const Text("هل أنت متأكد من حذف شركة الشحن هذه؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              ctrl.deleteShippingCompany(id);
              Navigator.pop(ctx);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}