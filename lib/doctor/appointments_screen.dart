import 'package:flutter/material.dart';

enum AppointmentStatus { pending, completed, cancelled }

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const appointments = <Map<String, dynamic>>[
      {
        'patient': 'ئاسو سەید',
        'time': '09:00',
        'status': AppointmentStatus.pending,
      },
      {
        'patient': 'ژین فەریق',
        'time': '10:30',
        'status': AppointmentStatus.completed,
      },
      {
        'patient': 'سۆران محەمەد',
        'time': '12:00',
        'status': AppointmentStatus.cancelled,
      },
      {
        'patient': 'هەنا عەبدولکریم',
        'time': '14:15',
        'status': AppointmentStatus.pending,
      },
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: 'گەڕانەوە',
          ),
          title: const Text(
            'نۆرەکانی ئەمڕۆ',
            style: TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: const Color(0xFF243B53),
          foregroundColor: const Color(0xFFD9E2EC),
          elevation: 0,
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: appointments.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = appointments[index];
            final status = item['status'] as AppointmentStatus;
            return _AppointmentCard(
              patientName: item['patient'].toString(),
              appointmentTime: item['time'].toString(),
              status: status,
            );
          },
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.patientName,
    required this.appointmentTime,
    required this.status,
  });

  final String patientName;
  final String appointmentTime;
  final AppointmentStatus status;

  Color get _statusColor => switch (status) {
        AppointmentStatus.pending => const Color(0xFFE6B800),
        AppointmentStatus.completed => const Color(0xFF28C76F),
        AppointmentStatus.cancelled => const Color(0xFFFF4D6D),
      };

  String get _statusText => switch (status) {
        AppointmentStatus.pending => 'چاوەڕێ',
        AppointmentStatus.completed => 'تەواوبوو',
        AppointmentStatus.cancelled => 'هەڵوەشاوە',
      };

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(
                    color: Color(0xFFD9E2EC),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'KurdishFont',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'کات: $appointmentTime',
                  style: const TextStyle(
                    color: Color(0xFF829AB1),
                    fontFamily: 'KurdishFont',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _statusColor.withOpacity(0.6)),
            ),
            child: Text(
              _statusText,
              style: TextStyle(
                color: _statusColor,
                fontWeight: FontWeight.w700,
                fontFamily: 'KurdishFont',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
