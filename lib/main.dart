import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const MerchantApp());
}

class MerchantApp extends StatelessWidget {
  const MerchantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تطبيق التاجر',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      ),
      home: const MerchantHomeScreen(),
    );
  }
}

class MerchantHomeScreen extends StatefulWidget {
  const MerchantHomeScreen({super.key});

  @override
  State<MerchantHomeScreen> createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends State<MerchantHomeScreen> {
  //final String serverUrl = 'http://localhost:3000';
  final String serverUrl = 'https://spare-parts-merchant.onrender.com'; // أو الرابط المباشر لسيرفرك
  List<dynamic> orders = [];
  Timer? _timer;

  final Map<String, TextEditingController> priceControllers = {};
  final Map<String, String> selectedQualityTypes = {}; 
  final Map<String, String> selectedQualityGrades = {}; 

  final List<String> qualityGradesList = ['درجة أولى', 'درجة ثانية', 'درجة ثالثة', 'غير معروف'];

  @override
  void initState() {
    super.initState();
    fetchOrders();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      fetchOrders();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    priceControllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  Future<void> fetchOrders() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/api/orders'));
      if (response.statusCode == 200) {
        final List<dynamic> fetchedOrders = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            orders = fetchedOrders;
            for (var order in orders) {
              String id = order['id'].toString();
              priceControllers.putIfAbsent(id, () => TextEditingController());
              selectedQualityTypes.putIfAbsent(id, () => 'أصلي');
              selectedQualityGrades.putIfAbsent(id, () => 'درجة أولى');
            }
          });
        }
      }
    } catch (e) {}
  }

  Future<void> sendOffer(String orderId) async {
    final priceStr = priceControllers[orderId]?.text.trim();
    final qualityType = selectedQualityTypes[orderId] ?? 'أصلي';
    final qualityGrade = selectedQualityGrades[orderId] ?? 'درجة أولى';

    if (priceStr == null || priceStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال السعر أولاً')));
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/api/orders/$orderId/offer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'price': double.tryParse(priceStr) ?? 0,
          'qualityType': qualityType,
          'qualityGrade': qualityGrade,
          'notes': '$qualityType ($qualityGrade)'
        }),
      );

      if (response.statusCode == 200) {
        await fetchOrders();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال العرض بنجاح!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Widget buildTypeOption(String orderId, String label) {
    bool isSelected = (selectedQualityTypes[orderId] ?? 'أصلي') == label;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            selectedQualityTypes[orderId] = label;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00695C) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? const Color(0xFF00695C) : Colors.grey.shade400),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التاجر - طلبات العملاء', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF00695C),
      ),
      body: orders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.hourglass_empty, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('في انتظار الطلبات...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                String orderId = order['id'].toString();
                String status = order['status'] ?? 'بانتظار العروض';
                String? partNum = order['partNumber'];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${order['carBrand']} ${order['carName']} (${order['carModel']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00695C))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: status.contains('تم') ? Colors.green.shade100 : Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: status.contains('تم') ? Colors.green.shade800 : Colors.amber.shade900)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('رقم الهيكل (VIN): ${order['vin'] ?? 'غير متوفر'}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 6),
                        
                        Text('القطعة المطلوبة: ${order['partName']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        if (partNum != null && partNum.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text('رقم القطعة (Part #): ', style: TextStyle(fontSize: 13, color: Colors.grey)),
                              Text(
                                partNum,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal),
                              ),
                            ],
                          ),
                        ],

                        const Divider(height: 20),

                        const Text('جودة القطعة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            buildTypeOption(orderId, 'أصلي'),
                            const SizedBox(width: 8),
                            buildTypeOption(orderId, 'تجاري'),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: selectedQualityGrades[orderId] ?? 'درجة أولى',
                                decoration: InputDecoration(
                                  labelText: 'درجة الجودة', 
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), 
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                ),
                                items: qualityGradesList.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                                onChanged: (val) => setState(() => selectedQualityGrades[orderId] = val!),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: priceControllers[orderId],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'السعر الإجمالي (ريال)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00695C),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => sendOffer(orderId),
                              child: const Text('إرسال العرض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}