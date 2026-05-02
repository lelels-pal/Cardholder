import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/history_entry.dart';

class DatabaseService {
  static const String _databaseName = 'cardikeep_history.db';
  static const String _tableName = 'history_entries';
  static const int _maxEntries = 25;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL,
        battery_level REAL,
        rssi INTEGER
      )
    ''');
  }

  Future<int> insertHistoryEntry(HistoryEntry entry) async {
    final db = await database;

    // Check current count and delete oldest if needed
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    ) ?? 0;

    if (count >= _maxEntries) {
      // Delete the oldest entry (smallest id)
      await db.rawDelete('''
        DELETE FROM $_tableName
        WHERE id = (SELECT MIN(id) FROM $_tableName)
      ''');
    }

    return await db.insert(_tableName, entry.toMap());
  }

  Future<List<HistoryEntry>> getHistoryEntries({int? limit}) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return maps.map((map) => HistoryEntry.fromMap(map)).toList();
  }

  Future<int> getEntryCount() async {
    final db = await database;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    ) ?? 0;
  }

  Future<int> deleteAllEntries() async {
    final db = await database;
    return await db.delete(_tableName);
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}