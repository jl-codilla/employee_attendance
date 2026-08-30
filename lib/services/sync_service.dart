import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'api_service.dart';
import 'local_database.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();

  SyncService._internal();

  bool _isSyncing = false;

  StreamSubscription<List<ConnectivityResult>>?
      _connectivitySubscription;

  void startListening() {
    if (_connectivitySubscription != null) return;

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(
      (results) async {
        print(
          'CONNECTIVITY: Changed to $results',
        );

        final hasNetwork = results.any(
          (result) =>
              result != ConnectivityResult.none,
        );

        if (hasNetwork) {
          print(
            'CONNECTIVITY: Network detected. '
            'Starting sync...',
          );

          await syncPendingAttendance();
        }
      },
    );
  }

  Future<bool> syncPendingAttendance() async {
    if (_isSyncing) {
      print('SYNC: Already syncing.');
      return false;
    }

    _isSyncing = true;

    bool allSynced = true;

    try {
      print('SYNC: Starting...');

      final pendingRecords =
          await LocalDatabase.instance
              .getPendingAttendance();

      for (final record in pendingRecords) {
      print(
        'PENDING: '
        'id=${record['id']} '
        'action=${record['action']} '
        'time=${record['created_at']}',
      );
}

      print(
        'SYNC: Found ${pendingRecords.length} pending records.',
      );

      for (final record in pendingRecords) {
        print(
          'SYNC: Processing ${record['action']} '
          'at ${record['created_at']}',
        );

        try {
          final action =
              record['action'].toString();

          final userUid =
              record['user_uid'].toString();

          final latitude =
              (record['latitude'] as num).toDouble();

          final longitude =
              (record['longitude'] as num).toDouble();

          final createdAt =
              DateTime.parse(
            record['created_at'].toString(),
          );

          Map<String, dynamic> response;

          if (action == 'TIME_IN') {
            print('SYNC: Sending TIME_IN to API...');

            response = await ApiService.timeIn(
              userUid: userUid,
              latitude: latitude,
              longitude: longitude,
              createdAt: createdAt,
            );
          } else if (action == 'TIME_OUT') {
            print('SYNC: Sending TIME_OUT to API...');

            response = await ApiService.timeOut(
              userUid: userUid,
              latitude: latitude,
              longitude: longitude,
              createdAt: createdAt,
            );
          } else {
            print(
              'SYNC: Unknown action $action. Deleting.',
            );

            await LocalDatabase.instance
                .deletePendingAttendance(
              record['id'] as int,
            );

            continue;
          }

          print('SYNC: API response: $response');

          if (response['success'] == true) {
            print(
              'SYNC: Success. Deleting local record '
              '${record['id']}',
            );

            await LocalDatabase.instance
                .deletePendingAttendance(
              record['id'] as int,
            );
          } else {
            print('SYNC: API returned failure.');

            allSynced = false;
            break;
          }
        } catch (error) {
          print(
            'SYNC: Error processing record: $error',
          );

          allSynced = false;
          break;
        }
      }
    } finally {
      _isSyncing = false;
    }

    print('SYNC: Finished. allSynced=$allSynced');

    return allSynced;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}