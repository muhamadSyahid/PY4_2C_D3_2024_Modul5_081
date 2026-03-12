import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:logbook_app_081/features/logbook/log_controller.dart';
import 'package:logbook_app_081/features/logbook/models/log_model.dart';
import 'package:logbook_app_081/features/auth/user_model.dart';
import 'package:logbook_app_081/services/access_control_service.dart';

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
      case 'Mechanical':
        return Colors.green.shade100;
      case 'Electronic':
        return Colors.blue.shade100;
      case 'Software':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade100;
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
    final userRole = User.current?.role ?? 'guest';
    final currentUserId = User.current?.id;
    final bool isOwner = log.authorId == currentUserId;
    final bool canDelete = AccessControlService.canPerform(
        userRole, AccessControlService.actionDelete,
        isOwner: isOwner);

    return Dismissible(
      key: Key(
          log.date.toIso8601String()), // Menggunakan tanggal sebagai key unik
      direction: canDelete
          ? DismissDirection.endToStart
          : DismissDirection.none, // Hanya swipe jika punya izin
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: canDelete
            ? const Icon(Icons.delete, color: Colors.white) // Show if true
            : const SizedBox.shrink(),
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
          leading: ValueListenableBuilder<Set<String>>(
            valueListenable: controller.pendingLogsNotifier,
            builder: (context, pendingIds, child) {
              final isPending = log.id != null && pendingIds.contains(log.id);
              return Icon(
                isPending ? Icons.cloud_off : Icons.cloud_done,
                color: isPending ? Colors.orange : Colors.green,
              );
            },
          ),
          title: Text('${log.title} (${log.category})'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 60,
                child: Markdown(
                  data: log.description,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'By ${log.authorId}',
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // GATEKEEPER: Tombol Edit
              if (AccessControlService.canPerform(
                userRole,
                AccessControlService.actionUpdate,
                isOwner: isOwner,
              ))
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    // Mencari index asli di list utama
                    final originalIndex = allLogs.indexOf(log);
                    onEdit(originalIndex, log);
                  },
                ),

              // GATEKEEPER: Tombol Delete (Optional jika ingin tombol selain swipe)
              if (AccessControlService.canPerform(
                userRole,
                AccessControlService.actionDelete,
                isOwner: isOwner,
              ))
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Hapus Catatan"),
                        content: const Text("Yakin ingin menghapus?"),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Batal")),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Hapus",
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      controller.removeLog(allLogs.indexOf(log));
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
