import 'package:flutter/material.dart';

class BarwarScreen extends StatefulWidget {
  const BarwarScreen({super.key});

  @override
  State<BarwarScreen> createState() => _BarwarScreenState();
}

class _BarwarScreenState extends State<BarwarScreen> {
  DateTime selectedDate = DateTime.now();
  String? selectedTime; // بۆ پاشەکەوتکردنی کاتی هەڵبژێردراو

  // لیستی کاتە نموونەییەکان
  final List<String> timeSlots = [
    '04:00 ئێوارە', '04:30 ئێوارە', '05:00 ئێوارە',
    '05:30 ئێوارە', '06:00 ئێوارە', '06:30 ئێوارە',
    '07:00 ئێوارە', '07:30 ئێوارە', '08:00 ئێوارە',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('دیاریکردنی نۆرە'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView( // بۆ ئەوەی ئەگەر شاشەکە بچووک بوو ئیرۆر نەدات
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('١. ڕۆژەکە هەڵبژێرە:', 
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                
                // --- خشتەی بەروار ---
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1E33),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: CalendarDatePicker(
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    onDateChanged: (date) => setState(() => selectedDate = date),
                  ),
                ),
                
                const SizedBox(height: 25),
                const Text('٢. کاتێکی گونجاو هەڵبژێرە:', 
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                // --- بەشی کاتەکان (Time Slots) ---
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: timeSlots.length,
                  itemBuilder: (context, index) {
                    bool isSelected = selectedTime == timeSlots[index];
                    return InkWell(
                      onTap: () => setState(() => selectedTime = timeSlots[index]),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blueAccent : const Color(0xFF1D1E33),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                        ),
                        child: Text(
                          timeSlots[index],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // --- دوگمەی کۆتایی ---
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: (selectedTime == null) ? null : () => _confirmBooking(),
                  child: const Text('پشتڕاستکردنەوەی نۆرە', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmBooking() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: Text(
          'نۆرەکەت تۆمارکرا بۆ ڕێکەوتی:\n${selectedDate.year}/${selectedDate.month}/${selectedDate.day}\nکاتژمێر: $selectedTime',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('گەڕانەوە بۆ سەرەتا'),
          ),
        ],
      ),
    );
  }
}