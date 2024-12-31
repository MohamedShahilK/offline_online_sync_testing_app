// Import necessary packages
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline-Online Sync',
      home: DataEntryScreen(),
    );
  }
}

class DataEntryScreen extends StatefulWidget {
  @override
  _DataEntryScreenState createState() => _DataEntryScreenState();
}

class _DataEntryScreenState extends State<DataEntryScreen> {
  late Database _database;
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isOnline = false;

  @override
  void initState() {
    super.initState();
    print('fffffffffffffffffffffffffffffff');
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await _initDatabase();
      await _checkConnectivity();

      if (isOnline) {
        await _fetchOnlineData();
      }
    });
  }

  Future<void> _fetchOnlineData() async {
    try {
      final snapshot = await _firestore.collection('entries').get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final docId = doc.id;
        final text = data['text'];

        final existingEntry = await _database.query('entries', where: 'id = ?', whereArgs: [docId]);
        if (existingEntry.isEmpty) {
          await _database.insert('entries', {
            'id': docId,
            'text': text,
            'synced': 1,
          });
        }
      }
    } catch (e) {
      print('Failed to fetch online data: $e');
    }
  }

  Future<void> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'entries.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE entries (id INTEGER PRIMARY KEY, text TEXT, synced INTEGER)',
        );
      },
    );
  }

  Future<void> _checkConnectivity() async {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) async {
      setState(() {
        isOnline = result.first != ConnectivityResult.none;
      });
      if (isOnline) {
        print('eeeeeeeeeeeeeeeeeeeeeeeeeee');
        await _syncData();
        // await _database.delete('entries');
        await _fetchOnlineData();
      }
    });
  }

  Future<void> _addEntry(String text) async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    await _database.insert('entries', {
      'id': newId,
      'text': text,
      'synced': 0,
    });
    if (isOnline) {
      await _syncData();
    }
  }

  Future<void> _syncData() async {
    final unsyncedData = await _database.query('entries', where: 'synced = ?', whereArgs: [0]);

    for (final entry in unsyncedData) {
      try {
        await _firestore.collection('entries').doc((entry['id'] as int).toString()).set({'text': entry['text']});
        await _database.update(
          'entries',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [entry['id']],
        );
        await _getEntries();
      } catch (e) {
        print('Failed to sync entry: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getEntries() async {
    return await _database.query('entries');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Offline-Online Sync App')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Enter data',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _addEntry(_controller.text);
              _controller.clear();
              setState(() {});
            },
            child: Text('Add Entry'),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getEntries(),
              builder: (context, snapshot) {
                print('55555555555555555555555555555555555555555555555555');
                if (!snapshot.hasData) {
                  return Center(child: Text('No Data Found'));
                }
                final entries = snapshot.data!;
                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return ListTile(
                      title: Text(entry['text']),
                      subtitle: Text(entry['synced'] == 1 ? 'Synced' : 'Unsynced'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _database.close();
    super.dispose();
  }
}
