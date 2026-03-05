import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logbook_app_081/features/logbook/log_controller.dart';
import 'package:logbook_app_081/features/logbook/models/log_model.dart';

class LogItemWidget extends StatelessWidget {
  final LogModel log;
  final List<LogModel> allLogs;
  final LogController controller;
  final Function(int, LogModel) onEdit;

  const LogItemWidget({
    super.key,
    required this.log,
    required this.allLogs,
    required this.controller,
    required this.onEdit,
  });

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Pekerjaan':
        return Colors.blue.shade100;
      case 'Urgent':
        return Colors.red.shade100;
      case 'Pribadi':
      default:
        return Colors.green.shade100;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari yang lalu';
    } else {
      // Menggunakan intl untuk format lokal Indonesia
      // Pastikan telah menambahkan intl: ^0.18.0 di pubspec.yaml
      return DateFormat('d MMM yyyy', 'id_ID').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(
          log.date.toIso8601String()), // Menggunakan tanggal sebagai key unik
      direction: DismissDirection.endToStart, // Hanya swipe dari kanan ke kiri
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Konfirmasi Hapus"),
              content:
                  const Text("Apakah Anda yakin ingin menghapus catatan ini?"),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("Batal")),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child:
                      const Text("Hapus", style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        controller.removeLog(allLogs.indexOf(log));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Catatan dihapus")),
        );
      },
      child: Card(
        color: _getCategoryColor(log.category),
        child: ListTile(
          // leading: const Icon(Icons.note),
          leading: const Icon(Icons.cloud_done, color: Colors.grey),
          title: Text('${log.title} (${log.category})'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(log.description),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'By ${log.user}',
                    style: const TextStyle(
                        fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                  Text(
                    _formatDate(log.date),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () {
              // Mencari index asli di list utama
              final originalIndex = allLogs.indexOf(log);
              onEdit(originalIndex, log);
            },
          ),
        ),
      ),
    );
  }
}
