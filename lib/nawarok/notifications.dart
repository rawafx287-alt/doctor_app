import 'package:flutter/material.dart';

import '../locale/app_locale.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('ئاگادارکردنەوەکان', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: AppLocaleScope.of(context).textDirection,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: 3, // ژمارەی ئاگادارکردنەوەکان
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1E33),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: index == 0 ? Colors.blueAccent : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: index == 0 ? Colors.blueAccent : Colors.grey.withOpacity(0.2),
                    child: Icon(
                      index == 0 ? Icons.check : Icons.notifications_none,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTitle(index),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _getMessage(index),
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    index == 0 ? 'ئێستا' : 'دوێنێ',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _getTitle(int index) {
    if (index == 0) return 'نۆرەکەت پشتڕاستکرایەوە';
    if (index == 1) return 'بیرخەرەوەی نۆرە';
    return 'بەخێرهاتیت';
  }

  String _getMessage(int index) {
    if (index == 0) return 'نۆرەکەت بۆ دکتۆر ئاراس لە کاتژمێر ٤:٣٠ وەرگیرا.';
    if (index == 1) return 'سبەی کاتژمێر ١٠:٠٠ بەیانی نۆرەت هەیە.';
    return 'سوپاس بۆ بەکارهێنانی ئەپی نور بۆ پزیشکان.';
  }
}