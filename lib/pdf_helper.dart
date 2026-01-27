import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;

class PdfHelper {
  
  static Future<Uint8List> generateBulkOrdersBytes(List<Map<String, dynamic>> orders) async {
    final pdf = pw.Document();
    
    // تحميل الخطوط
    var arabicFont = await PdfGoogleFonts.cairoRegular();
    var arabicBold = await PdfGoogleFonts.cairoBold();

    // تحميل اللوجو
    pw.MemoryImage? logoImage;
    try {
      final imageBytes = await rootBundle.load('assets/logo.png');
      logoImage = pw.MemoryImage(imageBytes.buffer.asUint8List());
    } catch (e) {
      logoImage = null;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        
        build: (pw.Context context) {
          return orders.map((order) {
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 30),
              child: _buildFinalBill(order, arabicBold, logoImage),
            );
          }).toList();
        },
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildFinalBill(Map<String, dynamic> order, pw.Font boldFont, pw.MemoryImage? logo) {
    double total = (order['total_price'] ?? 0) + (order['shipping_cost'] ?? 0);
    double remaining = total - (order['deposit'] ?? 0);
    const double rowHeight = 35.0; 

    // ✅ حدود سوداء صريحة
    final PdfColor borderColor = PdfColors.black;
    // ✅ سمك الخط 1.5 عشان يبقى واضح
    const double borderWidth = 1.5; 

    // تجهيز نص الموقع
    String locationText = "";
    if (order['client_gov'] != null && order['client_gov'].toString().isNotEmpty) {
      locationText += order['client_gov'];
    }
    if (order['client_region'] != null && order['client_region'].toString().isNotEmpty) {
      locationText += " - ${order['client_region']}";
    }

    return pw.Stack(
      children: [
        // 1. طبقة الخلفية (اللوجو الكبير الشفاف)
        if (logo != null)
          pw.Positioned(
            // 👇👇👇 التحكم في مكان اللوجو 👇👇👇
            top: 400, // زودت الرقم عشان ينزل لتحت (كان 350)
            left: 0,
            right: 0,
            child: pw.Opacity(
              opacity: 0.15, // شفافية خفيفة
              child: pw.Center(
                child: pw.Image(logo, width: 400), // حجم متوسط ومناسب
              ),
            ),
          ),

        // 2. طبقة المحتوى (البوليصة نفسها)
        pw.Container(
          child: pw.Column(
            children: [
              // --- الهيدر ---
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 15),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // اللوجو الصغير (شمال)
                    pw.Container(
                      width: 70,
                      alignment: pw.Alignment.centerLeft,
                      child: logo != null 
                        ? pw.Image(logo, height: 45) 
                        : pw.SizedBox(),
                    ),
                    
                    // اسم البراند (في النص)
                    pw.Expanded(
                      child: pw.Column(
                        children: [
                          pw.Text("Stticky", style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, font: boldFont)),
                          pw.Container(height: 2, width: 50, color: PdfColors.red),
                        ]
                      ),
                    ),

                    // مساحة وهمية يمين (عشان الاسم يفضل في النص)
                    pw.Container(width: 60),
                  ],
                ),
              ),

              // --- الجدول الرئيسي ---
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor, width: borderWidth),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // الجزء الأيمن (البيانات)
                    pw.Expanded(
                      flex: 65,
                      child: pw.Column(
                        children: [
                          _buildFieldRow("المرسل إليه", order['client_name'], rowHeight, borderColor, borderWidth),
                          _buildFieldRow("رقم التليفون", order['client_phone'], rowHeight, borderColor, borderWidth),
                          _buildFieldRow("المحافظة", locationText, rowHeight, borderColor, borderWidth),
                          _buildFieldRow("العنوان", order['client_address'], rowHeight, borderColor, borderWidth),
                          _buildFieldRow("ملاحظات", order['notes'] ?? '', rowHeight, borderColor, borderWidth, isLast: true),
                        ],
                      ),
                    ),

                    // الجزء الأيسر (الستيكر والتحصيل)
                    pw.Expanded(
                      flex: 35,
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border(right: pw.BorderSide(color: borderColor, width: borderWidth)),
                        ),
                        child: pw.Column(
                          children: [
                            // ستيكر
                            pw.Container(
                              height: rowHeight * 3,
                              width: double.infinity,
                              decoration: pw.BoxDecoration(
                                border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: borderWidth)),
                              ),
                              alignment: pw.Alignment.center,
                              child: pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text("ستيكر", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, font: boldFont)),
                                  pw.Text("Sticker", style: const pw.TextStyle(fontSize: 18)),
                                ]
                              )
                            ),
                            // تحصيل
                            pw.Container(
                              height: rowHeight,
                              decoration: pw.BoxDecoration(
                                border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: borderWidth)),
                              ),
                              child: pw.Row(
                                children: [
                                  pw.Container(
                                    width: 70,
                                    height: double.infinity,
                                    decoration: pw.BoxDecoration(
                                      border: pw.Border(right: pw.BorderSide(color: borderColor, width: borderWidth)),
                                    ),
                                    alignment: pw.Alignment.center,
                                    child: pw.Text("تحصيل", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                                  ),
                                  pw.Expanded(
                                    child: pw.Container(
                                      alignment: pw.Alignment.center,
                                      child: pw.FittedBox(
                                        fit: pw.BoxFit.scaleDown,
                                        child: pw.Text(
                                          "${remaining.toStringAsFixed(0)}", 
                                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // ID
                            pw.Container(
                              height: rowHeight,
                              alignment: pw.Alignment.center,
                              child: pw.Text("#${order['id']}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)), 
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFieldRow(String label, String? value, double height, PdfColor borderCol, double width, {bool isLast = false}) {
    final String safeValue = value ?? "";
    
    return pw.Container(
      height: height,
      decoration: pw.BoxDecoration(
        border: isLast ? null : pw.Border(bottom: pw.BorderSide(color: borderCol, width: width)),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 80, 
            height: double.infinity,
            decoration: pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(color: borderCol, width: width)),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          ),
          
          pw.Expanded(
            child: pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.symmetric(horizontal: 5),
              child: safeValue.trim().isEmpty 
                  ? null 
                  : pw.FittedBox(
                      fit: pw.BoxFit.scaleDown,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        safeValue, 
                        textDirection: pw.TextDirection.rtl,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
  
  // ✅ دالة المالية (كاملة الآن)
  static Future<Uint8List> generateFinanceReportBytes(List<Map<String, dynamic>> transactions, double totalBalance) async {
    final pdf = pw.Document();
    var arabicFont = await PdfGoogleFonts.cairoRegular();
    final dateFormat = intl.DateFormat('yyyy/MM/dd');

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: arabicFont),
        ),
        build: (pw.Context context) {
          return [
             pw.Header(level: 0, child: pw.Center(child: pw.Text("تقرير الخزنة", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)))),
             pw.SizedBox(height: 20),
             
             // جدول المعاملات
             pw.Directionality(
               textDirection: pw.TextDirection.rtl,
               child: pw.Table.fromTextArray(
                 headers: ['التاريخ', 'الوصف', 'نوع الحركة', 'المبلغ'],
                 data: transactions.map((trans) => [
                   dateFormat.format(DateTime.parse(trans['date'])),
                   trans['title'],
                   trans['isIncome'] == 1 ? 'إيراد' : 'مصروف',
                   trans['amount'].toStringAsFixed(2),
                 ]).toList(),
                 headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                 headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
                 cellAlignment: pw.Alignment.center,
                 cellAlignments: {1: pw.Alignment.centerRight},
               ),
             ),
             
             pw.SizedBox(height: 20),
             
             // الإجمالي النهائي
             pw.Row(
               mainAxisAlignment: pw.MainAxisAlignment.end,
               children: [
                 pw.Text("${totalBalance.toStringAsFixed(2)} ج.م", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: totalBalance >= 0 ? PdfColors.green : PdfColors.red)),
                 pw.Text(" :الرصيد النهائي", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
               ]
             )
          ];
        },
      ),
    );
    return await pdf.save();
  }
}