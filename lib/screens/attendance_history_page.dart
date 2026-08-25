import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({super.key});

  @override
  State<AttendanceHistoryPage> createState() =>
      _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState
    extends State<AttendanceHistoryPage> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _userUid;

  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final uid = prefs.getString('employee_uid');

      if (uid == null || uid.isEmpty) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        return;
      }

      _userUid = uid;

      final response = await supabase
          .from('attendance_logs')
          .select(
            'id, action, latitude, longitude, created_at',
          )
          .eq('user_uid', uid)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _history = List<Map<String, dynamic>>.from(
          response,
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Unable to load attendance history. '
        'Check your internet connection and try again.',
      );
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

    return '${dateTime.month}/${dateTime.day}/${dateTime.year} '
        '$hour:$minute $period';
  }

  String _formatAction(String action) {
    switch (action) {
      case 'TIME_IN':
        return 'Time In';

      case 'TIME_OUT':
        return 'Time Out';

      default:
        return action;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'TIME_IN':
        return Icons.login;

      case 'TIME_OUT':
        return Icons.logout;

      default:
        return Icons.access_time;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: _history.isEmpty
                  ? ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Text(
                            'No attendance records yet.',
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _history.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final record = _history[index];

                        final action =
                            record['action'].toString();

                        final dateTime = DateTime.parse(
                          record['created_at'].toString(),
                        ).toLocal();

                        final latitude = 
                            record['latitude'].toString();

                        final longitude =
                            record['longitude'].toString();

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              _getActionIcon(action),
                            ),
                            title: Text(
                              _formatAction(action),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              _formatDateTime(dateTime),
                            ),
                            trailing: Text(
                              'Lat: $latitude\nLng: $longitude',
                              textAlign: TextAlign.right,
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}