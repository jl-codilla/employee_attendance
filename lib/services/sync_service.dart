import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'api_service.dart';
import 'local_database.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();

  SyncService._internal();

  bool _isSyncing = false;

  void Function(int syncedCount)? onSyncComplete;

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

            final synced =
                await syncPendingAttendance();

            if (synced > 0) {
              onSyncComplete?.call(synced);
              // print(
              //   'SYNC: Attendance data synced successfully.',
              // );
            }
          }
        },
      );
    }

  Future<int> syncPendingAttendance() async {
    if (_isSyncing) {
      print('SYNC: Already syncing.');
      return 0;
    }

    _isSyncing = true;

    int syncedCount = 0;

    try {
      print('SYNC: Starting...');

      final pendingRecords =
          await LocalDatabase.instance
              .getPendingAttendance();

      if (pendingRecords.isEmpty) {
        print('SYNC: No pending records.');
        return 0;
      }       

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

            syncedCount++;
          } else {
            print('SYNC: API returned failure.');
            break;
          }
        } catch (error) {
          print(
            'SYNC: Error processing record: $error',
          );
          break;
        }
      }
    } finally {
      _isSyncing = false;
    }

    print('SYNC: Finished. syncedCount=$syncedCount');

    return syncedCount;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}