import 'package:hive/hive.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'log_model.g.dart';

@HiveType(typeId: 0)
class LogModel {
  @HiveField(0)
  final String? id; // Penanda unik global dari MongoDB
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String description;
  @HiveField(3)
  final DateTime date;
  @HiveField(4)
  final String category;
  @HiveField(5)
  final String authorId;
  @HiveField(6)
  final String teamId;
  @HiveField(7)
  final bool isPublic;

  LogModel({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.category,
    required this.authorId,
    required this.teamId,
    this.isPublic = false,
  });

  // [CONVERT] Memasukkan data ke "Kardus" (BSON/Map) untuk dikirim ke Cloud
  Map<String, dynamic> toMap() {
    return {
      '_id': id != null
          ? ObjectId.fromHexString(id!)
          : ObjectId(), // Buat ID otomatis jika belum ada
      'title': title,
      'description': description,
      'date': date.toIso8601String(), // Simpan tanggal dalam format standar
      'category': category,
      'authorId': authorId,
      'teamId': teamId,
      'isPublic': isPublic,
    };
  }

  // [REVERT] Membongkar "Kardus" (BSON/Map) kembali menjadi objek Flutter
  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      id: (map['_id'] as ObjectId?)?.oid,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      category: map['category'] ?? '',
      authorId: map['authorId'] ?? 'unknown_user',
      teamId: map['teamId'] ?? 'no_team',
      isPublic: map['isPublic'] ?? false,
    );
  }
}
