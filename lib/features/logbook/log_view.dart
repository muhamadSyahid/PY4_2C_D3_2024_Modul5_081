import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:logbook_app_081/features/auth/login_view.dart';
import 'package:logbook_app_081/features/logbook/log_controller.dart';
import 'package:logbook_app_081/features/logbook/log_editor_page.dart';
import 'package:logbook_app_081/features/logbook/widgets/log_item_widget.dart';
import 'package:logbook_app_081/features/logbook/models/log_model.dart';
import 'package:logbook_app_081/helpers/log_helper.dart';
import 'package:logbook_app_081/services/mongo_service.dart';
import 'package:logbook_app_081/features/auth/user_model.dart';

class LogView extends StatefulWidget {
  final User currentUser;
  const LogView({super.key, required this.currentUser});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  LogController _controller = LogController();
  // final currentUser = User.current; // Removed local variable
  // bool _isLoading = false;
  bool _isOffline = false; // Status offline

  // 1. Tambahkan Controller untuk menangkap input di dalam State
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _controller = LogController();

    // Memberikan kesempatan UI merender widget awal sebelum proses berat dimulai
    _controller.loadLogs(widget.currentUser.teamId);
    Future.microtask(() => _initDatabase());

    // START AUTO-SYNC LISTENER
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        // Jika koneksi kembali normal, lakukan sinkronisasi
        _initDatabase();
      }
    });
  }

  void _goToEditor({LogModel? log, int? index}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogEditorPage(
          log: log,
          index: index,
          controller: _controller,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _initDatabase() async {
    setState(() {
      // _isLoading = true;
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

      // Mengambil data log dari Cloud & Sync Pending Data
      await LogHelper.writeLog(
        "UI: Syncing with Cloud (loadLogs)...",
        source: "log_view.dart",
      );

      // Panggil loadLogs untuk:
      // 1. Upload data offline (Pending Inserts)
      // 2. Download data terbaru dari Cloud
      // 3. Merge data
      await _controller.loadLogs(widget.currentUser.teamId);

      await LogHelper.writeLog(
        "UI: Data berhasil dimuat & disinkronisasi.",
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
      // if (mounted) {
      //   setState(() => _isLoading = false);
      // }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // void _showAddLogDialog() {
  //   String selectedCategory = 'Pribadi';
  //   showDialog(
  //     context: context,
  //     builder: (context) => StatefulBuilder(
  //       builder: (context, setDialogState) => AlertDialog(
  //         title: const Text("Tambah Catatan Baru"),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min, // Agar dialog tidak memenuhi layar
  //           children: [
  //             TextField(
  //               controller: _titleController,
  //               decoration: const InputDecoration(hintText: "Judul Catatan"),
  //             ),
  //             TextField(
  //               controller: _contentController,
  //               decoration: const InputDecoration(hintText: "Isi Deskripsi"),
  //             ),
  //             DropdownButtonFormField<String>(
  //               value: selectedCategory,
  //               items: _categories.map((String category) {
  //                 return DropdownMenuItem<String>(
  //                   value: category,
  //                   child: Text(category),
  //                 );
  //               }).toList(),
  //               onChanged: (String? newValue) {
  //                 if (newValue != null) {
  //                   setDialogState(() {
  //                     selectedCategory = newValue;
  //                   });
  //                 }
  //               },
  //               decoration: const InputDecoration(hintText: "Kategori"),
  //             ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context), // Tutup tanpa simpan
  //             child: const Text("Batal"),
  //           ),
  //           ElevatedButton(
  //             onPressed: () {
  //               // Jalankan fungsi tambah di Controller
  //               _controller.addLog(_titleController.text,
  //                   _contentController.text, selectedCategory);

  //               // Bersihkan input dan tutup dialog
  //               _titleController.clear();
  //               _contentController.clear();
  //               Navigator.pop(context);
  //             },
  //             child: const Text("Simpan"),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // void _showEditLogDialog(int index, LogModel log) {
  //   _titleController.text = log.title;
  //   _contentController.text = log.description;
  //   String selectedCategory = log.category;

  //   showDialog(
  //     context: context,
  //     builder: (context) => StatefulBuilder(
  //       builder: (context, setDialogState) => AlertDialog(
  //         title: const Text("Edit Catatan"),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             TextField(controller: _titleController),
  //             TextField(controller: _contentController),
  //             DropdownButtonFormField<String>(
  //               value: selectedCategory,
  //               items: _categories.map((String category) {
  //                 return DropdownMenuItem<String>(
  //                   value: category,
  //                   child: Text(category),
  //                 );
  //               }).toList(),
  //               onChanged: (String? newValue) {
  //                 if (newValue != null) {
  //                   setDialogState(() {
  //                     selectedCategory = newValue;
  //                   });
  //                 }
  //               },
  //               decoration: const InputDecoration(hintText: "Kategori"),
  //             ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //               onPressed: () => Navigator.pop(context),
  //               child: const Text("Batal")),
  //           ElevatedButton(
  //             onPressed: () {
  //               _controller.updateLog(index, _titleController.text,
  //                   _contentController.text, selectedCategory);
  //               _titleController.clear();
  //               _contentController.clear();
  //               Navigator.pop(context);
  //             },
  //             child: const Text("Update"),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _goToEditor(), // Panggil fungsi dialog yang baru dibuat
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
            "Logbook: ${widget.currentUser.username} (${widget.currentUser.role} (${widget.currentUser.teamId}))"),
        titleTextStyle: TextStyle(fontSize: 10),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.loadLogs(widget.currentUser.teamId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
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
                                builder: (context) => const LoginView()),
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
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {}),
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
                // 1. Ambil data user/tim
                final userLogs =
                    _controller.getLogsByUser(widget.currentUser.teamId);

                // 2. Cek Empty State (Data Kosong)
                if (userLogs.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.dashboard_customize_outlined,
                            size: 120,
                            color: Colors.teal,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Belum ada aktivitas hari ini?",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Mulai catat kemajuan proyek Anda!",
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => _goToEditor(),
                            icon: const Icon(Icons.add),
                            label: const Text("Buat Catatan Baru"),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // 3. Filter Search (Judul & Isi)
                final query = _searchController.text.toLowerCase();
                final filteredLogs = userLogs.where((log) {
                  final title = log.title.toLowerCase();
                  final content = log.description.toLowerCase();
                  return title.contains(query) || content.contains(query);
                }).toList();

                // 4. Cek Pencarian Kosong
                if (filteredLogs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off,
                            size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          "Tidak ditemukan catatan untuk \"${_searchController.text}\"",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // 5. Tampilkan List
                return RefreshIndicator(
                  onRefresh: _initDatabase,
                  child: ListView.builder(
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      // final bool isOwner =
                      //     log.authorId == widget.currentUser.id;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: LogItemWidget(
                            log: log,
                            allLogs: currentLogs,
                            controller: _controller,
                            onEdit: (originalIndex, logModel) {
                              _goToEditor(log: log, index: originalIndex);
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
