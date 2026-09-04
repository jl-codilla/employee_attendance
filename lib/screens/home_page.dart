// packages
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

// services
import '../services/api_service.dart';
import '../services/local_database.dart';
import '../services/sync_service.dart';

// pages
import 'attendance_history_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  bool _isClockedIn = false;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isSigningOut = false;
  bool _isLoadingHistory = true;

  DateTime? _timeIn;
  DateTime? _timeOut;

  String? _employeeName;
  String? _employeeNumber;

  List<Map<String, dynamic>> _recentHistory = [];

  String? _userUid;

  @override
  void initState() {
    super.initState();

    SyncService.instance.onSyncComplete = (syncedCount) {
      if (!mounted) return;

      _showMessage(
        '$syncedCount attendance record(s) synced successfully.',
      );

      _loadAttendanceStatus();
      _loadRecentHistory();
    };

    _initializeHome();
  }

  Future<void> _initializeHome() async {
    final prefs = await SharedPreferences.getInstance();

    final uid = prefs.getString('employee_uid');

    if (uid == null || uid.isEmpty) {
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
        (route) => false,
      );

      return;
    }

    _userUid = uid;

    // synchronize any offline attendance records.
    await SyncService.instance.syncPendingAttendance();

    await Future.wait([
      _loadProfile(),
      _loadAttendanceStatus(),
      _loadRecentHistory(),
    ]);
  }

  Future<void> _loadProfile() async {
    if (_userUid == null) return;

    try {
      final response = await ApiService.getProfile(
        userUid: _userUid!,
      );

      if (!mounted) return;

      if (response['success'] != true) {
        throw Exception(
          response['message'] ?? 'Unable to load profile.',
        );
      }

      final user = response['user'];

      setState(() {
        _employeeName = user['full_name']?.toString();
        _employeeNumber = user['employee_id']?.toString();
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Unable to load employee information. '
        'Check your internet connection and try again.',
      );
    }
  }

  Future<void> _loadAttendanceStatus() async {
    if (_userUid == null) return;

    try {
      final response = await ApiService.getAttendanceStatus(
        userUid: _userUid!,
      );

      if (!mounted) return;

      if (response['success'] != true) {
        throw Exception(
          response['message'] ?? 'Unable to load attendance status.',
        );
      }

      final isTimedIn = response['is_timed_in'] == true;

      DateTime? timeIn;
      DateTime? timeOut;

      if (response['time_in'] != null) {
        timeIn = DateTime.parse(
          response['time_in'].toString(),
        ).toLocal();
      }

      if (response['time_out'] != null) {
        timeOut = DateTime.parse(
          response['time_out'].toString(),
        ).toLocal();
      }

      setState(() {
        _isClockedIn = isTimedIn;
        _timeIn = timeIn;
        _timeOut = timeOut;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Unable to load attendance status. '
        'Check your internet connection and try again.',
      );
    }
  }

  Future<void> _loadRecentHistory() async {
    if (_userUid == null) return;

    try {
      final response = await ApiService.getAttendanceHistory(
        userUid: _userUid!,
      );

      if (!mounted) return;

      if (response['success'] != true) {
        throw Exception(
          response['message'] ?? 'Unable to load attendance history.',
        );
      }

      final records = List<Map<String, dynamic>>.from(
        response['attendance'] ?? [],
      );

      setState(() {
        _recentHistory = records.take(10).toList();
        _isLoadingHistory = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingHistory = false;
      });

      _showMessage(
        'Unable to load attendance history. '
        'Check your internet connection and try again.',
      );
    }
  }

  Future<Position?> _getLocation() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      _showMessage('Please enable location services.');
      return null;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        _showMessage('Location permission denied.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showMessage(
        'Location permission permanently denied. '
        'Enable it in settings.',
      );
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _timeInAction() async {
    if (_userUid == null) {
      _showMessage('You are not signed in.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final position = await _getLocation();

      if (position == null) return;

      final createdAt = DateTime.now();

      // ALWAYS save locally first.
      await LocalDatabase.instance.insertPendingAttendance(
        userUid: _userUid!,
        action: 'TIME_IN',
        latitude: position.latitude,
        longitude: position.longitude,
        createdAt: createdAt,
      );

      // Immediately update the UI.
      if (mounted) {
        setState(() {
          _isClockedIn = true;
          _timeIn = createdAt;
          _timeOut = null;
        });
      }

      // Try to sync to MSSQL.
      final synced =
          await SyncService.instance.syncPendingAttendance();

      if (!mounted) return;

      if (synced > 0) {
        await _loadAttendanceStatus();
        await _loadRecentHistory();

        if (!mounted) return;

        _showMessage(
          'Time in recorded successfully.',
        );
      } else {
        _showMessage(
          'Time in saved locally. '
          'It will sync when internet is available.',
        );
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Unable to record attendance. Please try again.',
      );  
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _timeOutAction() async {
    if (_userUid == null) {
      _showMessage('You are not signed in.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final position = await _getLocation();

      if (position == null) return;

      final createdAt = DateTime.now();

      // ALWAYS save locally first.
      await LocalDatabase.instance.insertPendingAttendance(
        userUid: _userUid!,
        action: 'TIME_OUT',
        latitude: position.latitude,
        longitude: position.longitude,
        createdAt: createdAt,
      );

      // Immediately update the UI.
      if (mounted) {
        setState(() {
          _isClockedIn = false;
          _timeOut = createdAt;
        });
      }

      // Try to sync.
      final synced =
          await SyncService.instance.syncPendingAttendance();

      if (!mounted) return;

      if (synced > 0) {
        await _loadAttendanceStatus();
        await _loadRecentHistory();

        if (!mounted) return;

        _showMessage(
          'Time out recorded successfully.',
        );
      } else {
        _showMessage(
          'Time out saved locally. '
          'It will sync when internet is available.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('employee_uid');
      await prefs.remove('employee_id');
      await prefs.remove('full_name');

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSigningOut = false;
      });

      _showMessage('Failed to sign out. Please try again.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : dateTime.hour == 0
            ? 12
            : dateTime.hour;

    final minute =
        dateTime.minute.toString().padLeft(2, '0');

    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '${dateTime.month}/${dateTime.day} '
        '$hour:$minute $period';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : time.hour == 0
            ? 12
            : time.hour;

    final minute =
        time.minute.toString().padLeft(2, '0');

    final period = time.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String _formatAction(String action) {
    if (action == 'TIME_IN') {
      return 'Time In';
    }

    if (action == 'TIME_OUT') {
      return 'Time Out';
    }

    return action;
  }

  IconData _actionIcon(String action) {
    if (action == 'TIME_IN') {
      return Icons.login;
    }

    return Icons.logout;
  }

  String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: _isSigningOut ? null : _signOut,
          ),
        ],
      ),
      body: _isSigningOut
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Signing out...',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      _loadAttendanceStatus(),
                      _loadRecentHistory(),
                    ]);
                  },
                  child: SingleChildScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        // Removed image

                        // const SizedBox(height: 24),

                        // const Icon(
                        //   Icons.badge_outlined,
                        //   size: 70,
                        // ),

                        // const SizedBox(height: 24),

                        const Text(
                          'Welcome!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          _employeeName ?? 'Employee',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Employee ID: ${_employeeNumber ?? ''}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 32),

                        Card(
                          child: Padding(
                            padding:
                                const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Text(
                                  'Attendance Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                Text(
                                  _isClockedIn
                                      ? 'Timed In'
                                      : 'Not Timed In',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                if (_isClockedIn &&
                                    _timeIn != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Since ${_formatTime(_timeIn!)}',
                                    style:
                                        const TextStyle(
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isProcessing
                                ? null
                                : (_isClockedIn
                                    ? _timeOutAction
                                    : _timeInAction),
                            child: _isProcessing
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isClockedIn ? 'TIME OUT' : 'TIME IN',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Card(
                          child: Padding(
                            padding:
                                const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current Attendance',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                Row(
                                  children: [
                                    const Icon(
                                      Icons.login,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Time In',
                                      style: TextStyle(
                                        fontWeight:
                                            FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _timeIn != null
                                          ? _formatDateTime(
                                              _timeIn!,
                                            )
                                          : '--',
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    const Icon(
                                      Icons.logout,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Time Out',
                                      style: TextStyle(
                                        fontWeight:
                                            FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _timeOut != null
                                          ? _formatDateTime(
                                              _timeOut!,
                                            )
                                          : '--',
                                    ),
                                  ],
                                ),

                                if (_timeIn != null &&
                                    _timeOut != null) ...[
                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.timer_outlined,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Total',
                                        style: TextStyle(
                                          fontWeight:
                                              FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatDuration(
                                          _timeIn!,
                                          _timeOut!,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Card(
                          child: Padding(
                            padding:
                                const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Attendance History (Limit 10)',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(
                                          context,
                                        ).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const AttendanceHistoryPage(),
                                          ),
                                        );
                                      },
                                      child:
                                          const Text('View All'),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                if (_isLoadingHistory)
                                  const Center(
                                    child:
                                        Padding(
                                      padding:
                                          EdgeInsets.all(16),
                                      child:
                                          CircularProgressIndicator(),
                                    ),
                                  )
                                else if (_recentHistory
                                    .isEmpty)
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'No attendance records yet.',
                                      ),
                                    ),
                                  )
                                else
                                  ..._recentHistory.map(
                                    (record) {
                                      final action =
                                          record['action']
                                              .toString();

                                      final longitude =
                                          record['longitude']
                                              .toString();
                                              
                                      final latitude =
                                          record['latitude']
                                              .toString();

                                      final dateTime =
                                          DateTime.parse(
                                        record['created_at']
                                            .toString(),
                                      ).toLocal();

                                      return Padding(
                                        padding:
                                            const EdgeInsets
                                                .only(
                                          bottom: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _actionIcon(
                                                action,
                                              ),
                                            ),

                                            const SizedBox(
                                              width: 12,
                                            ),

                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  Text(
                                                    _formatAction(
                                                      action,
                                                    ),
                                                    style:
                                                        const TextStyle(
                                                      fontWeight:
                                                          FontWeight
                                                              .w500,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    height: 2,
                                                  ),
                                                  Text(
                                                    _formatDateTime(
                                                      dateTime,
                                                    ),
                                                    style:
                                                        TextStyle(
                                                      fontSize:
                                                          13,
                                                      color: Colors
                                                          .grey[
                                                              600],
                                                    ),
                                                  ),
                                                  Text(
                                                    'Lat: $latitude, Long: $longitude',
                                                    style:
                                                        TextStyle(
                                                      fontSize:
                                                          13,
                                                      color: Colors
                                                          .grey[
                                                              600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }
}