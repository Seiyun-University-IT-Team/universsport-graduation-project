import 'package:flutter/material.dart';
import '../../models/registration_model.dart';
import '../../repositories/registration_repository.dart';
import '../../services/notification_service.dart';

class ManageRegistrationsScreen extends StatefulWidget {
  const ManageRegistrationsScreen({super.key});

  @override
  State<ManageRegistrationsScreen> createState() => _ManageRegistrationsScreenState();
}

class _ManageRegistrationsScreenState extends State<ManageRegistrationsScreen> {
  final RegistrationRepository _registrationRepository = RegistrationRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات التسجيل'),
      ),
      body: StreamBuilder<List<RegistrationModel>>(
        stream: _registrationRepository.getPendingRegistrations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ في جلب البيانات'));
          }

          final registrations = snapshot.data ?? [];

          if (registrations.isEmpty) {
            return const Center(child: Text('لا توجد طلبات تسجيل معلقة.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: registrations.length,
            itemBuilder: (context, index) {
              final reg = registrations[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'طلب تسجيل جديد',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '\${reg.registrationDate.day}/\${reg.registrationDate.month}/\${reg.registrationDate.year}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('رقم الطالب (User ID): \${reg.userId}'),
                      Text('رقم الرياضة (Sport ID): \${reg.sportId}'),
                      if (reg.competitionId != null)
                        Text('رقم البطولة: \${reg.competitionId}'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () async {
                              await _registrationRepository.updateRegistrationStatus(reg.id, 'rejected');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('رفض'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              await _registrationRepository.updateRegistrationStatus(reg.id, 'approved');
                              
                              // Local notification simulation for demonstration
                              final notificationService = NotificationService();
                              await notificationService.showLocalNotification(
                                title: "تم القبول!",
                                body: "لقد تم قبول تسجيلك في الرياضة بنجاح.",
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('قبول'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
