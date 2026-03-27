import 'package:flutter/material.dart';

class ApprovalListScreen extends StatefulWidget {
  const ApprovalListScreen({super.key});

  @override
  State<ApprovalListScreen> createState() => _ApprovalListScreenState();
}

class _ApprovalListScreenState extends State<ApprovalListScreen> {
  final List<_DoctorRequest> _requests = [
    const _DoctorRequest(name: 'د. ئارام عوسمان', specialty: 'دڵ'),
    const _DoctorRequest(name: 'د. شیرین حەمە', specialty: 'منداڵان'),
    const _DoctorRequest(name: 'د. سامان عەلی', specialty: 'پێست'),
  ];

  void _approve(int index) {
    final item = _requests[index];
    setState(() {
      _requests.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('قبوڵکرا: ${item.name}')),
    );
  }

  void _reject(int index) {
    final item = _requests[index];
    setState(() {
      _requests.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ڕەتکرایەوە: ${item.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'داواکارییەکان',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _requests.isEmpty
            ? const Center(
                child: Text(
                  'هیچ داواکارییەک نییە',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(18),
                itemBuilder: (context, index) {
                  final item = _requests[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1E33),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'پسپۆڕی: ${item.specialty}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  minimumSize: const Size(double.infinity, 46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => _approve(index),
                                child: const Text(
                                  '✅ قبوڵکردن',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Colors.redAccent,
                                    width: 1.2,
                                  ),
                                  minimumSize: const Size(double.infinity, 46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => _reject(index),
                                child: const Text(
                                  '❌ ڕەتکردنەوە',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemCount: _requests.length,
              ),
      ),
    );
  }
}

class _DoctorRequest {
  const _DoctorRequest({required this.name, required this.specialty});
  final String name;
  final String specialty;
}

