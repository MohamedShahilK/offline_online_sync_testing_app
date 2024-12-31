import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

class SyncService {
  final Database localDb;

  SyncService(this.localDb);

  Future<void> syncData() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.first == ConnectivityResult.none) {
      print('No internet connection.');
      return;
    }

    // Fetch unsynced data from local DB
    final unsyncedData = await localDb.query('entries', where: 'synced = ?', whereArgs: [0]);

    for (final entry in unsyncedData) {
      try {
        // Push data to the online database
        await uploadToServer(entry);

        // Mark as synced locally
        await localDb.update(
          'entries',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [entry['id']],
        );
      } catch (e) {
        print('Error syncing entry ${entry['id']}: $e');
      }
    }
  }

  Future<void> uploadToServer(Map<String, dynamic> data) async {
    // Implement your server upload logic here
  }
}
