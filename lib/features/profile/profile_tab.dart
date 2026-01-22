import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../../core/logging/log_service.dart';
import '../../models/log_entry.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final LogService _logService = LogService();
  bool _loading = false;

  void _log(String msg, {LogLevel level = LogLevel.info}) {
    _logService.log('PROFILE', msg, level: level);
  }

  Future<void> _refreshUserData() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      // This will trigger a reload of user devices
      await auth.refreshUserData();
    } catch (e) {
      _log('Failed to refresh user data: $e', level: LogLevel.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh data: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _log('User initiated logout');
      context.read<AuthProvider>().logout();
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('User Profile'),
            backgroundColor: Theme.of(context).primaryColor,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loading ? null : _refreshUserData,
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 24),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'User Information',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                'Username',
                                auth.username ?? 'Unknown',
                                Icons.person_outline,
                                () => _copyToClipboard(auth.username ?? '', 'Username'),
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'User UUID',
                                auth.uuid ?? 'Unknown',
                                Icons.fingerprint,
                                () => _copyToClipboard(auth.uuid ?? '', 'User UUID'),
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Backend URL',
                                auth.backendUrl ?? 'Not set',
                                Icons.link,
                                () => _copyToClipboard(auth.backendUrl ?? '', 'Backend URL'),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Devices Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.devices, size: 24),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'My Devices',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${auth.userDevices?['devices']?.length ?? 0} devices',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildDevicesList(auth.userDevices?['devices'] ?? []),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Session Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.security, size: 24),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Session Status',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(
                                    auth.isSessionValid ? Icons.check_circle : Icons.warning,
                                    color: auth.isSessionValid ? Colors.green : Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    auth.isSessionValid ? 'Session Valid' : 'Session Invalid',
                                    style: TextStyle(
                                      color: auth.isSessionValid ? Colors.green : Colors.orange,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.copy, size: 16, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesList(List<dynamic> devices) {
    if (devices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          children: [
            Icon(Icons.device_hub, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No devices found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Connect your first IoT device in the Setup tab',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: devices.map<Widget>((device) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.router,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device['device_name'] ?? 'Unknown Device',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (device['device_id'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${device['device_id']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.circle,
                size: 12,
                color: Colors.green, // Assume connected for now
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}