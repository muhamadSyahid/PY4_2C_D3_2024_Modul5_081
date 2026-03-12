import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logbook_app_081/helpers/log_helper.dart';
import 'package:logbook_app_081/services/access_control_service.dart';
import 'package:logbook_app_081/services/mongo_service.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logbook_app_081/features/logbook/models/log_model.dart';
import 'package:logbook_app_081/features/auth/user_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LogController {
  final hiveBox = Hive.box<LogModel>('localstorage');
  final ValueNotifier<List<LogModel>> logsNotifier = ValueNotifier([]);
  final ValueNotifier<Set<String>> pendingLogsNotifier = ValueNotifier({});

  static const String _storageKey = 'user_logs_data';
  static const String _pendingInsertsKey = 'pending_inserts';
  static const String _pendingUpdatesKey = 'pending_updates';
  static const String _pendingDeletesKey = 'pending_deletes';

  List<LogModel> getLogsByUser(String currentUser) {
    return logsNotifier.value
        .where((log) => log.teamId == currentUser)
        .toList();
  }

  LogController() {
    final user = User.current;
    if (user != null) {
      loadFromDisk(user.teamId);
    }
  }

  Future<void> _refreshPendingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final pInserts = prefs.getStringList(_pendingInsertsKey) ?? [];
    final pUpdates = prefs.getStringList(_pendingUpdatesKey) ?? [];
    pendingLogsNotifier.value = {...pInserts, ...pUpdates};
  }

  // --- HELPER UNTUK SYNC OFFLINE ---
  Future<void> _addPendingInsert(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pending = prefs.getStringList(_pendingInsertsKey) ?? [];
    if (!pending.contains(id)) {
      pending.add(id);
      await prefs.setStringList(_pendingInsertsKey, pending);
      _refreshPendingStatus();
    }
  }

  Future<void> _addPendingUpdate(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pending = prefs.getStringList(_pendingUpdatesKey) ?? [];
    if (!pending.contains(id)) {
      pending.add(id);
      await prefs.setStringList(_pendingUpdatesKey, pending);
      _refreshPendingStatus();
    }
  }

  Future<void> _addPendingDelete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pending = prefs.getStringList(_pendingDeletesKey) ?? [];
    if (!pending.contains(id)) {
      pending.add(id);
      await prefs.setStringList(_pendingDeletesKey, pending);
    }
  }

  Future<void> _syncAllPending() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pendingInserts =
        prefs.getStringList(_pendingInsertsKey) ?? [];
    final List<String> pendingUpdates =
        prefs.getStringList(_pendingUpdatesKey) ?? [];
    final List<String> pendingDeletes =
        prefs.getStringList(_pendingDeletesKey) ?? [];

    if (pendingInserts.isEmpty &&
        pendingUpdates.isEmpty &&
        pendingDeletes.isEmpty) return;

    await LogHelper.writeLog(
        "SYNC: Memproses antrian offline (I:${pendingInserts.length}, U:${pendingUpdates.length}, D:${pendingDeletes.length})...");

    // 1. SYNC INSERTS
    if (pendingInserts.isNotEmpty) {
      List<String> successIds = [];
      for (String id in pendingInserts) {
        try {
          final logToSync = hiveBox.values.firstWhere(
            (l) => l.id == id,
            orElse: () => throw Exception('LogDeletedLocally'),
          );
          await MongoService().insertLog(logToSync);
          successIds.add(id);
        } catch (e) {
          if (e.toString().contains('LogDeletedLocally')) successIds.add(id);
        }
      }
      if (successIds.isNotEmpty) {
        final updated =
            pendingInserts.where((id) => !successIds.contains(id)).toList();
        await prefs.setStringList(_pendingInsertsKey, updated);
      }
    }

    // 2. SYNC UPDATES
    if (pendingUpdates.isNotEmpty) {
      List<String> successIds = [];
      for (String id in pendingUpdates) {
        try {
          final logToSync = hiveBox.values.firstWhere(
            (l) => l.id == id,
            orElse: () => throw Exception('LogDeletedLocally'),
          );
          await MongoService().updateLog(logToSync);
          successIds.add(id);
        } catch (e) {
          if (e.toString().contains('LogDeletedLocally')) successIds.add(id);
        }
      }
      if (successIds.isNotEmpty) {
        final updated =
            pendingUpdates.where((id) => !successIds.contains(id)).toList();
        await prefs.setStringList(_pendingUpdatesKey, updated);
      }
    }

    // 3. SYNC DELETES
    if (pendingDeletes.isNotEmpty) {
      List<String> successIds = [];
      for (String id in pendingDeletes) {
        try {
          // Hanya ID yang dibutuhkan untuk delete
          await MongoService().deleteLog(ObjectId.fromHexString(id));
          successIds.add(id);
        } catch (e) {
          // ignore error
        }
      }
      if (successIds.isNotEmpty) {
        final updated =
            pendingDeletes.where((id) => !successIds.contains(id)).toList();
        await prefs.setStringList(_pendingDeletesKey, updated);
      }
    }

    await _refreshPendingStatus();
  }

  /// 1. LOAD DATA (Offline-First Strategy)
  Future<void> loadLogs(String teamId) async {
    // Langkah 1: Ambil data dari Hive (Sangat Cepat/Instan)
    logsNotifier.value = hiveBox.values.cast<LogModel>().toList();

    // Langkah 2: Sync dari Cloud (Background)
    try {
      // PROSES SYNC: Coba upload data offline yang tertunda
      await _syncAllPending();

      final cloudData = await MongoService().getLogs(teamId);

      if (cloudData.isNotEmpty) {
        // MERGE DATA: Offline Wins!
        // Ambil data perubahan lokal yang mungkin belum terkirim
        final prefs = await SharedPreferences.getInstance();
        final pInserts = prefs.getStringList(_pendingInsertsKey) ?? [];
        final pUpdates = prefs.getStringList(_pendingUpdatesKey) ?? [];
        final pDeletes = prefs.getStringList(_pendingDeletesKey) ?? [];

        // 1. Mulai dengan data dari Cloud
        final mergedMap = {for (var log in cloudData) log.id: log};

        // 2. Override dengan data lokal yang belum tersinkron (Insert & Update)
        // Kita ambil versi terbaru dari Hive saat ini (karena Hive = Single Source of Truth lokal)
        final allLocalLogs = hiveBox.values.cast<LogModel>();
        for (var id in [...pInserts, ...pUpdates]) {
          try {
            final localLog = allLocalLogs.firstWhere((l) => l.id == id);
            mergedMap[id!] = localLog; // Timpa data cloud dengan lokal
          } catch (_) {}
        }

        // 3. Hapus data yang seharusnya sudah didelete (tapi belum sync ke cloud)
        for (var id in pDeletes) {
          mergedMap.remove(id);
        }

        // 4. Simpan hasil merge ke Hive & Update UI
        await hiveBox.clear();
        await hiveBox.addAll(mergedMap.values);
        logsNotifier.value = hiveBox.values.cast<LogModel>().toList();
      }
    } catch (e) {
      // If cloud fails, we just keep the Hive data already in the notifier
      await LogHelper.writeLog("OFFLINE: Using Hive cache ($e)", level: 2);
    }
  }

  /// 2. ADD DATA (Instant Local + Background Cloud)
  Future<void> addLog(
    String title,
    String desc,
    String category,
    String authorId,
    String teamId,
  ) async {
    final newLog = LogModel(
      id: ObjectId().oid, // Menggunakan .oid (String) untuk Hive
      title: title,
      description: desc,
      date: DateTime.now(),
      category: category,
      authorId: authorId,
      teamId: teamId,
    );

    // ACTION 1: Simpan ke Hive (Instan)
    await hiveBox.add(newLog);
    final currentList = List<LogModel>.from(logsNotifier.value);
    currentList.add(newLog);
    logsNotifier.value = currentList;

    // ACTION 2: Kirim ke MongoDB Atlas (Background)
    try {
      await MongoService().insertLog(newLog);
      await LogHelper.writeLog(
        "SUCCESS: Data tersinkron ke Cloud",
        source: "log_controller.dart",
      );
    } catch (e) {
      // Jika gagal koneksi (OFFLINE), simpan ID ke antrian
      await _addPendingInsert(newLog.id!);
      await LogHelper.writeLog(
        "WARNING: Data tersimpan lokal, antrian sync dibuat.",
        level: 1,
      );
    }
  }

  // 2. Memperbarui data (Offline-First: Lokal Dulu, Cloud Belakangan)
  Future<void> updateLog(
      int index, String newTitle, String newDesc, String newCat) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final oldLog = currentLogs[index];

    final updatedLog = LogModel(
      id: oldLog.id, // ID harus tetap sama agar MongoDB mengenali dokumen ini
      title: newTitle,
      description: newDesc,
      date: DateTime.now(),
      category: newCat,
      authorId: oldLog.authorId,
      teamId: oldLog.teamId,
    );

    // 1. Update Lokal (Instant UI Update)
    currentLogs[index] = updatedLog;
    logsNotifier.value = currentLogs;

    // 2. Update Persistensi Lokal (Hive)
    // Mencari key log yang sesuai di Hive untuk di-update
    final keyToUpdate = hiveBox.keys.firstWhere((k) {
      final val = hiveBox.get(k);
      return val?.id == oldLog.id;
    }, orElse: () => null);

    if (keyToUpdate != null) {
      await hiveBox.put(keyToUpdate, updatedLog);
    }

    // 3. Sinkronisasi ke Cloud (Background)
    try {
      await MongoService().updateLog(updatedLog);

      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Update '${oldLog.title}' Berhasil",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      // OFFLINE: Simpan ID ke antrian
      if (oldLog.id != null) {
        await _addPendingUpdate(oldLog.id!);
      }
      await LogHelper.writeLog(
        "WARNING: Offline Mode. Update tersimpan lokal: $e",
        source: "log_controller.dart",
        level: 1,
      );
    }
  }

  // 3. Menghapus data (Offline-First & Fix Crash)
  Future<void> removeLog(int index) async {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final targetLog = currentLogs[index];

    final currentUser = User.current;
    if (currentUser == null) {
      await LogHelper.writeLog("ERROR: No user logged in during delete attempt",
          level: 1);
      return;
    }

    // Cek izin (sudah divalidasi juga di UI, tapi double check di sini)
    if (!AccessControlService.canPerform(currentUser.role, 'delete',
        isOwner: targetLog.authorId == currentUser.id)) {
      await LogHelper.writeLog("SECURITY BREACH: Unauthorized delete attempt",
          level: 1);
      return;
    }

    // 1. Hapus UI & Memory (Instant)
    currentLogs.removeAt(index);
    logsNotifier.value = currentLogs;

    // 2. Hapus dari Hive (Persistensi Lokal)
    final keyToDelete = hiveBox.keys.firstWhere((k) {
      final val = hiveBox.get(k);
      return val?.id == targetLog.id;
    }, orElse: () => null);

    if (keyToDelete != null) {
      await hiveBox.delete(keyToDelete);
    }

    // 3. Hapus dari Cloud (Background)
    try {
      if (targetLog.id == null) {
        throw Exception(
          "ID Log tidak ditemukan, tidak bisa menghapus di Cloud.",
        );
      }

      // FIX: Gunakan ObjectId.fromHexString() bukan casting langsung
      await MongoService().deleteLog(ObjectId.fromHexString(targetLog.id!));

      await LogHelper.writeLog(
        "SUCCESS: Sinkronisasi Hapus '${targetLog.title}' Berhasil",
        source: "log_controller.dart",
        level: 2,
      );
    } catch (e) {
      // OFFLINE: Simpan ID ke antrian
      if (targetLog.id != null) {
        await _addPendingDelete(targetLog.id!);
      }
      await LogHelper.writeLog(
        "WARNING: Offline Mode. Hapus tersimpan lokal: $e",
        source: "log_controller.dart",
        level: 1,
      );
    }
  }

  // --- Functions below might be deprecated or unused but kept for compatibility ---

  Future<void> saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData =
        jsonEncode(logsNotifier.value.map((e) => e.toMap()).toList());
    await prefs.setString(_storageKey, encodedData);
  }

  Future<void> loadFromDisk(String teamId) async {
    // 1. First, load what we have in Hive immediately
    logsNotifier.value = hiveBox.values.cast<LogModel>().toList();

    // 2. Then, try to refresh from Cloud in the background
    await loadLogs(teamId);
  }
}
