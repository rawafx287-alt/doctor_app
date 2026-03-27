import 'package:flutter/material.dart';

import '../app_rtl.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _patients = const [
    {'name': 'ئاوات محەمەد', 'age': 34},
    {'name': 'ژیان عەزیز', 'age': 27},
    {'name': 'رێناس حەمە', 'age': 41},
    {'name': 'ساران ئەحمەد', 'age': 30},
    {'name': 'هۆنیا عومەر', 'age': 22},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final filteredPatients = _patients.where((patient) {
      if (query.isEmpty) return true;
      return patient['name'].toString().toLowerCase().contains(query.toLowerCase());
    }).toList();

    return Directionality(
      textDirection: kRtlTextDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: 'گەڕانەوە',
          ),
          title: const Text(
            'لیستی نەخۆشەکان',
            style: TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: const Color(0xFF243B53),
          foregroundColor: const Color(0xFFD9E2EC),
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _SearchField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: filteredPatients.isEmpty
                    ? const Center(
                        child: Text(
                          'هیچ نەخۆشێک نەدۆزرایەوە',
                          style: TextStyle(
                            color: Color(0xFF829AB1),
                            fontFamily: 'KurdishFont',
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filteredPatients.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final patient = filteredPatients[index];
                          return _PatientCard(
                            name: patient['name'].toString(),
                            age: patient['age'] as int,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          color: Color(0xFFD9E2EC),
          fontFamily: 'KurdishFont',
        ),
        decoration: const InputDecoration(
          hintText: 'گەڕان بە ناوی نەخۆش...',
          hintStyle: TextStyle(
            color: Color(0xFF829AB1),
            fontFamily: 'KurdishFont',
          ),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF2CB1BC)),
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({
    required this.name,
    required this.age,
  });

  final String name;
  final int age;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2CB1BC).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_rounded, color: Color(0xFF2CB1BC)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFFD9E2EC),
                    fontFamily: 'KurdishFont',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تەمەن: $age ساڵ',
                  style: const TextStyle(
                    color: Color(0xFF829AB1),
                    fontFamily: 'KurdishFont',
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('بەزوویی: مێژووی نەخۆش')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2CB1BC),
              foregroundColor: const Color(0xFF102A43),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'بینینی مێژوو',
              style: TextStyle(
                fontFamily: 'KurdishFont',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
