import 'package:flutter/material.dart';
import 'package:logbook_app_081/features/logbook/log_controller.dart';
import 'package:logbook_app_081/features/logbook/widgets/log_item_widget.dart';
import 'package:logbook_app_081/features/onboarding/onboarding_view.dart';
import 'package:logbook_app_081/features/logbook/models/log_model.dart';
import 'package:logbook_app_081/helpers/log_helper.dart';
import 'package:logbook_app_081/services/mongo_service.dart';

class LogView extends StatefulWidget {
  final String username;
  const LogView({super.key, required this.username});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  LogController _controller = LogController();
  bool _isLoading = false;
  bool _isOffline = false; // Status offline

  // 1. Tambahkan Controller untuk menangkap input di dalam State
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ['Pekerjaan', 'Pribadi', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _controller = LogController();

    // Memberikan kesempatan UI merender widget awal sebelum proses berat dimulai
    Future.microtask(() => _initDatabase());
  }

  Future<void> _initDatabase() async {
    setState(() {
      _isLoading = true;
      _isOffline = false;
    });
    try {
      await LogHelper.writeLog(
        "UI: Memulai inisialisasi database...",
        source: "log_view.dart",
      );

      // Mencoba koneksi ke MongoDB Atlas (Cloud)
      await LogHelper.writeLog(
        "UI: Menghubungi MongoService.connect()...",
        source: "log_view.dart",
      );

      // Mengaktifkan kembali koneksi dengan timeout 15 detik (lebih longgar untuk sinyal HP)
      await MongoService().connect().timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception(
              "Koneksi Cloud Timeout. Periksa sinyal/IP Whitelist.",
            ),
          );

      await LogHelper.writeLog(
        "UI: Koneksi MongoService BERHASIL.",
        source: "log_view.dart",
      );

      // Mengambil data log dari Cloud
      await LogHelper.writeLog(
        "UI: Memanggil controller.loadFromDisk()...",
        source: "log_view.dart",
      );

      await _controller.loadFromDisk();

      await LogHelper.writeLog(
        "UI: Data berhasil dimuat ke Notifier.",
        source: "log_view.dart",
      );
    } catch (e) {
      await LogHelper.writeLog(
        "UI: Error - $e",
        source: "log_view.dart",
        level: 1,
      );
      setState(() => _isOffline = true); // Tandai sebagai offline

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOffline
                ? "⚠️ Mode Offline: Tidak dapat terhubung ke server."
                : "Masalah: $e"),
            backgroundColor: _isOffline ? Colors.orange : Colors.red,
            action: SnackBarAction(
              label: 'Coba Lagi',
              textColor: Colors.white,
              onPressed: _initDatabase,
            ),
          ),
        );
      }
    } finally {
      // 2. INILAH FINALLY: Apapun yang terjadi (Sukses/Gagal/Data Kosong), loading harus mati
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddLogDialog() {
    String selectedCategory = 'Pribadi';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Tambah Catatan Baru"),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Agar dialog tidak memenuhi layar
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: "Judul Catatan"),
              ),
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(hintText: "Isi Deskripsi"),
              ),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setDialogState(() {
                      selectedCategory = newValue;
                    });
                  }
                },
                decoration: const InputDecoration(hintText: "Kategori"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Tutup tanpa simpan
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () {
                // Jalankan fungsi tambah di Controller
                _controller.addLog(widget.username, _titleController.text,
                    _contentController.text, selectedCategory);

                // Bersihkan input dan tutup dialog
                _titleController.clear();
                _contentController.clear();
                Navigator.pop(context);
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLogDialog(int index, LogModel log) {
    _titleController.text = log.title;
    _contentController.text = log.description;
    String selectedCategory = log.category;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit Catatan"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _titleController),
              TextField(controller: _contentController),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setDialogState(() {
                      selectedCategory = newValue;
                    });
                  }
                },
                decoration: const InputDecoration(hintText: "Kategori"),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Batal")),
            ElevatedButton(
              onPressed: () {
                _controller.updateLog(index, _titleController.text,
                    _contentController.text, selectedCategory);
                _titleController.clear();
                _contentController.clear();
                Navigator.pop(context);
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLogDialog, // Panggil fungsi dialog yang baru dibuat
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("Logbook: ${widget.username}"),
        actions: [
          IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text("Konfirmasi Logout"),
                      content: const Text(
                          "Apakah Anda yakin? Data yang belum disimpan mungkin akan hilang."),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Batal"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const OnboardingView()),
                              (route) => false,
                            );
                          },
                          child: const Text("Ya, Keluar",
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(Icons.logout))
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cari Catatan',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<LogModel>>(
              valueListenable: _controller.logsNotifier,
              builder: (context, currentLogs, child) {
                if (_isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Menghubungkan ke MongoDB Atlas..."),
                      ],
                    ),
                  );
                }

                // 2. Tampilan jika loading sudah selesai tapi data di Atlas kosong
                final userLogs = _controller.getLogsByUser(widget.username);
                final filteredLogs = userLogs
                    .where((log) => log.title
                        .toLowerCase()
                        .contains(_searchController.text.toLowerCase()))
                    .toList();

                if (filteredLogs.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _initDatabase,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize
                                .min, // Changed to min for better centering
                            mainAxisAlignment:
                                MainAxisAlignment.center, // Center vertically
                            children: [
                              Icon(
                                _isOffline
                                    ? Icons.signal_wifi_off
                                    : Icons.cloud_off,
                                size: 64,
                                color: _isOffline ? Colors.orange : Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isOffline
                                    ? "Anda sedang offline.\nTarik ke bawah untuk mencoba lagi."
                                    : "Belum ada catatan di Cloud.\nTarik ke bawah untuk memuat ulang.",
                                textAlign: TextAlign.center,
                              ),
                              if (!_isOffline) ...[
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _showAddLogDialog,
                                  child: const Text("Buat Catatan Pertama"),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // Jika data sudah masuk, tampilkan List seperti biasa
                return RefreshIndicator(
                  onRefresh: _initDatabase,
                  child: ListView.builder(
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: LogItemWidget(
                            log: log,
                            allLogs: currentLogs,
                            controller: _controller,
                            onEdit: (originalIndex, logModel) {
                              _showEditLogDialog(originalIndex, log);
                            }),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
