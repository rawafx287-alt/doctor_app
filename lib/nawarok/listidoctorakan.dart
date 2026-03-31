import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import 'barwar.dart';

class ListiDoctorakanScreen extends StatefulWidget {
  const ListiDoctorakanScreen({super.key});

  @override
  State<ListiDoctorakanScreen> createState() => _ListiDoctorakanScreenState();
}

class _ListiDoctorakanScreenState extends State<ListiDoctorakanScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('دۆزینەوەی پزیشک', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: AppLocaleScope.of(context).textDirection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ١. بەشی گەڕان
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1E33),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const TextField(
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'گەڕان بۆ ناوی پزیشک...',
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.search, color: Colors.blueAccent),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ),

            // ٢. بەشی پۆلێنکردن (Categories)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: Text('پۆلێنەکان', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                children: [
                  _categoryItem(Icons.favorite, 'دڵ'),
                  _categoryItem(Icons.visibility, 'چاو'),
                  _categoryItem(Icons.child_care, 'منداڵان'),
                  _categoryItem(Icons.medical_services, 'گشتی'),
                  _categoryItem(Icons.biotech, 'تاقیگە'),
                  _categoryItem(Icons.psychology, 'دەروونی'),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Text('پزیشکە پێشنیارکراوەکان', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),

            // ٣. لیستی پزیشکەکان بە ئەنیمەیشن
            Expanded(
              child: ListView.builder(
                itemCount: 6,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemBuilder: (context, index) {
                  return TweenAnimationBuilder(
                    duration: Duration(milliseconds: 400 + (index * 150)),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.1)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Hero(
                          tag: 'doc_img_$index',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl:
                                  'https://img.freepik.com/free-photo/smiling-doctor-with-white-coat_23-2148827750.jpg',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              memCacheWidth: 120,
                              memCacheHeight: 120,
                              fadeInDuration: Duration.zero,
                            ),
                          ),
                        ),
                        title: Text('دکتۆر ئاراس ئەحمەد ${index + 1}', 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: const Text('پسپۆڕی نەخۆشییەکانی دڵ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.blueAccent, size: 16),
                        onTap: () => _showDoctorProfile(context, 'دکتۆر ئاراس ئەحمەد ${index + 1}', index),
                      ),
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

  // دروستکردنی ئایکۆنی پۆلێنەکان
  Widget _categoryItem(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF1D1E33),
            child: Icon(icon, color: Colors.blueAccent, size: 28),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  void _showDoctorProfile(BuildContext context, String name, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1D1E33),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              Hero(
                tag: 'doc_img_$index',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: CachedNetworkImage(
                    imageUrl:
                        'https://img.freepik.com/free-photo/smiling-doctor-with-white-coat_23-2148827750.jpg',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    memCacheWidth: 200,
                    memCacheHeight: 200,
                    fadeInDuration: Duration.zero,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(name, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
              const Text('پسپۆڕی نەخۆشییەکانی دڵ', style: TextStyle(color: Colors.blueAccent)),
              const Divider(color: Colors.white10, height: 40),
              _infoRow(Icons.access_time, 'کاتی دەوام', '٤ی ئێوارە - ٩ی شەو'),
              _infoRow(Icons.location_on, 'ناونیشان', 'سلێمانی - شەقامی پزیشکان'),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const BarwarScreen()));
                },
                child: const Text('گرتنی نۆرە', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 15),
          Text('$title: ', style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
