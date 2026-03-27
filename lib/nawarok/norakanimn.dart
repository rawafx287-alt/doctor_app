import 'package:flutter/material.dart';

import '../app_rtl.dart';

class NorekaniMinScreen extends StatelessWidget {
  const NorekaniMinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21), // ڕەنگی پشتێنەی ئەپەکە
      appBar: AppBar(
        title: const Text('نۆرەکانی من', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: kRtlTextDirection,
        child: Column(
          children: [
            const SizedBox(height: 10),
            // لیستەکە لێرە دەست پێ دەکات
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: 2, // لێرەدا ژمارەی ئەو نۆرانە دادەنێین کە حجز کراون
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1E33), // ڕەنگی ناو کارتەکان
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.blueAccent,
                              child: Icon(Icons.person, color: Colors.white, size: 35),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    index == 0 ? 'دکتۆر ئاراس ئەحمەد' : 'دکتۆرە سارا عەلی',
                                    style: const TextStyle(
                                      color: Colors.white, 
                                      fontSize: 18, 
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                  const Text('پسپۆڕی نەخۆشییەکانی دڵ', 
                                    style: TextStyle(color: Colors.blueAccent, fontSize: 14)),
                                ],
                              ),
                            ),
                            const Icon(Icons.info_outline, color: Colors.grey, size: 20),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 25),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.grey, size: 16),
                                const SizedBox(width: 5),
                                Text(index == 0 ? '٢٠٢٦/٠٣/٢٧' : '٢٠٢٦/٠٤/٠٢', 
                                  style: const TextStyle(color: Colors.grey, fontSize: 14)),
                                const SizedBox(width: 15),
                                const Icon(Icons.access_time, color: Colors.grey, size: 16),
                                const SizedBox(width: 5),
                                Text(index == 0 ? '١٠:٠٠ بەیانی' : '٠٤:٣٠ ئێوارە', 
                                  style: const TextStyle(color: Colors.grey, fontSize: 14)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('پەسەندکراو', 
                                style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}