// Import necessary packages
import 'package:flutter/material.dart';
import 'package:rxdart/subjects.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final isSyncingNotifier = ValueNotifier<bool>(false);

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

  final ticketsStream = BehaviorSubject<List<Map<String, dynamic>>>.seeded([]);

  @override
  void initState() {
    super.initState();
    // print('fffffffffffffffffffffffffffffff');
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await _initDatabase();
      await _checkConnectivity();

      // await deleteDatabase(join(await getDatabasesPath(), 'entries.db'));

      if (isOnline) {
        await _fetchOnlineData();
      }
    });
  }

  Future<void> _fetchOnlineData() async {
    await _database.delete('entries').then((va) async {
      try {
        final snapshot = await _firestore.collection('entries').get();
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final docId = doc.id;
          // final text = data['text'];
          final text = data['ticket_number'];

          final existingEntry = await _database.query('entries', where: 'id = ?', whereArgs: [docId]);
          if (existingEntry.isEmpty) {
            // await _database.insert('entries', {
            //   'id': docId,
            //   'text': text,
            //   'synced': 1,
            // });

            await _database.insert('entries', {
              'synced': 1,
              'id': docId,
              'ticket_number': text,
              'mobile_number': '',
              'car_brand': '',
              'car_color': '',
            });
          }
        }
        // await _getEntries();
        final tickets = await _database.query('entries');
        ticketsStream.add(tickets);
        // print('222222222222222222222222222222222 ${await _database.query('entries')}');
      } catch (e) {
        print('Failed to fetch online data: $e');
      }
    });
  }

  Future<void> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'entries.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          // 'CREATE TABLE entries (id INTEGER PRIMARY KEY, text TEXT, synced INTEGER)',
          'CREATE TABLE entries (id INTEGER PRIMARY KEY, ticket_number TEXT,mobile_number TEXT,car_brand TEXT,car_color TEXT, synced INTEGER)',
        );
      },
    );
  }

  Future<void> _checkConnectivity() async {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) async {
      setState(() {
        isOnline = result.first != ConnectivityResult.none;
      });

      // print('3333333333333333333333333333333333333333333 $isOnline');

      if (isOnline) {
        await _syncData();
        await _fetchOnlineData();
      }
    });
  }

  Future<void> _addEntry(String text) async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    // await _database.insert('entries', {
    //   'id': newId,
    //   'text': text,
    //   'synced': 0,
    // });

    await _database.insert('entries', {
      'synced': 0,
      'id': newId,
      'ticket_number': text,
      'mobile_number': 'asd',
      'car_brand': 'asd',
      'car_color': 'asd',
    });

    print('3333333333333333333333333333333333333333333 $isOnline');
    if (isOnline) {
      final tickets = await _database.query('entries');
      ticketsStream.add(tickets);
      await _syncData();
      await _fetchOnlineData();
      // await _syncData();
      // await _fetchOnlineData();
    } else {
      final tickets = await _database.query('entries');
      ticketsStream.add(tickets);
    }
  }

  Future<void> _syncData() async {
    isSyncingNotifier.value = true;
    isSyncingNotifier.notifyListeners();
    final unsyncedData = await _database.query('entries', where: 'synced = ?', whereArgs: [0]);

    // Future.delayed(
    //   Duration(seconds: 1),
    //   () async {

    //   },
    // );

    for (final entry in unsyncedData) {
      try {
        // await _firestore.collection('entries').doc((entry['id'] as int).toString()).set({
        //   'id': entry['id'],
        //   'text': entry['text'],
        //   // 'synced': entry['synced'],
        // });

        await _firestore.collection('entries').doc((entry['id'] as int).toString()).set({
          'id': entry['id'],
          'ticket_number': entry['ticket_number'],
          'mobile_number': entry['mobile_number'],
          'car_brand': entry['car_brand'],
          'car_color': entry['car_color'],
          // 'synced': entry['synced'],
        });
        await _database.update(
          'entries',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [entry['id']],
        );
        // await _getEntries();
        final tickets = await _database.query('entries');
        ticketsStream.add(tickets);
      } catch (e) {
        print('Failed to sync entry: $e');
      }
    }
    isSyncingNotifier.value = false;
    isSyncingNotifier.notifyListeners();
  }

  // Future<List<Map<String, dynamic>>> _getEntries() async {
  //   return await _database.query('entries');
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder(
          valueListenable: isSyncingNotifier,
          builder: (context, sync, _) {
            // print('33333333333333333333333333 ${isSyncingNotifier.value}');
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Offline-Online Sync App'),
                if (isSyncingNotifier.value) Text('Syncing ....', style: TextStyle(fontSize: 13)),
              ],
            );
          },
        ),
      ),
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
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: ticketsStream, // Use Stream instead of Future
              builder: (context, snapshot) {
                print('Syncing');
                if (!snapshot.hasData) {
                  return Center(child: Text('No Data Found'));
                }
                final entries = snapshot.data!;
                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return ListTile(
                      title: Text(entry['ticket_number']),
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
