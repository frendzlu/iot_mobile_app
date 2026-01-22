import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/ble/bluetooth_service.dart';
import '../../models/provisioning_config.dart';
import '../../models/device_status.dart';
import '../auth/auth_provider.dart';

class SetupDeviceTab extends StatefulWidget {
  const SetupDeviceTab({super.key});

  @override
  State<SetupDeviceTab> createState() => _SetupDeviceTabState();
}

class _SetupDeviceTabState extends State<SetupDeviceTab> {
  BluetoothDevice? _selectedDevice;
  
  // Provisioning form controllers
  final _deviceNameController = TextEditingController();
  final _ssidController = TextEditingController();
  final _wifiPasswordController = TextEditingController();
  final _backendUrlController = TextEditingController();
  final _brokerUrlController = TextEditingController();

  bool _showProvisioningForm = false;
  bool _isProvisioning = false;
  bool _showUnnamedDevices = false;
  DeviceStatus? _lastDeviceStatus;
  
  @override
  void initState() {
    super.initState();
    // Listen for device status updates
    _listenToDeviceStatus();
  }
  
  void _listenToDeviceStatus() {
    context.read<IoTBluetoothService>().deviceStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _lastDeviceStatus = status;
        });
        
        // Show status updates in snackbars
        _showStatusUpdate(status);
      }
    });
  }
  
  void _showStatusUpdate(DeviceStatus status) {
    String message = '';
    Color backgroundColor = Colors.blue;
    
    if (status.errorMessage != null) {
      message = 'Error: ${status.errorMessage}';
      backgroundColor = Colors.red;
    } else if (status.isFullyProvisioned) {
      message = 'Device fully provisioned and registered!';
      backgroundColor = Colors.green;
    } else {
      // Show incremental progress
      final updates = <String>[];
      if (status.isWifiConnected) updates.add('WiFi connected${status.wifiSsid != null ? ' to ${status.wifiSsid}' : ''}');
      if (status.isMqttConnected) updates.add('MQTT connected');
      if (status.isRegistered) updates.add('Device registered');
      
      if (updates.isNotEmpty) {
        message = updates.last;
        backgroundColor = Colors.green;
      }
    }
    
    if (message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Device Setup'),
        actions: [
          Consumer<IoTBluetoothService>(
            builder: (context, bluetooth, _) {
              if (bluetooth.isConnected) {
                return IconButton(
                  icon: const Icon(Icons.bluetooth_connected),
                  onPressed: () => bluetooth.disconnect(),
                  tooltip: 'Disconnect',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<IoTBluetoothService>(
        builder: (context, bluetooth, _) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Device Selection Section
                _buildDeviceSelectionSection(bluetooth),
                
                const SizedBox(height: 20),
                
                // Provisioning Form Section
                if (_showProvisioningForm) _buildProvisioningSection(bluetooth),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeviceSelectionSection(IoTBluetoothService bluetooth) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bluetooth Devices',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: bluetooth.isScanning ? null : () => bluetooth.startScan(),
                    icon: bluetooth.isScanning 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(bluetooth.isScanning ? 'Scanning...' : 'Scan for Devices'),
                  ),
                ),
                const SizedBox(width: 8),
                if (bluetooth.isConnected)
                  ElevatedButton.icon(
                    onPressed: () => bluetooth.disconnect(),
                    icon: const Icon(Icons.bluetooth_disabled),
                    label: const Text('Disconnect'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Filter toggle
            Row(
              children: [
                Checkbox(
                  value: _showUnnamedDevices,
                  onChanged: (value) {
                    setState(() => _showUnnamedDevices = value ?? false);
                    // Also update the logging filter in bluetooth service
                    bluetooth.showUnnamedDevicesInLogs = _showUnnamedDevices;
                  },
                ),
                const Text('Show unnamed devices'),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Device List
            if (_getFilteredDevices(bluetooth).isNotEmpty)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _getFilteredDevices(bluetooth).length,
                  itemBuilder: (context, index) {
                    final device = _getFilteredDevices(bluetooth)[index];
                    final isConnected = bluetooth.connectedDevice?.id == device.id;
                    final hasName = device.name.isNotEmpty;
                    
                    return ListTile(
                      leading: Icon(
                        isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                        color: isConnected ? Colors.green : null,
                      ),
                      title: Text(
                        hasName ? device.name : 'Unknown Device',
                        style: TextStyle(
                          fontWeight: hasName ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(device.id.toString()),
                      trailing: isConnected 
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : ElevatedButton(
                              onPressed: () => _connectToDevice(device, bluetooth),
                              child: const Text('Connect'),
                            ),
                      selected: _selectedDevice?.id == device.id,
                      onTap: () => setState(() => _selectedDevice = device),
                    );
                  },
                ),
              )
            else
              Container(
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'No devices found. Tap "Scan for Devices" to start.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProvisioningSection(IoTBluetoothService bluetooth) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Provisioning',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _deviceNameController,
              decoration: const InputDecoration(
                labelText: 'Device Name *',
                hintText: 'Enter a name for this device',
                prefixIcon: Icon(Icons.device_hub),
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _ssidController,
              decoration: const InputDecoration(
                labelText: 'WiFi SSID *',
                hintText: 'Enter your WiFi network name',
                prefixIcon: Icon(Icons.wifi),
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _wifiPasswordController,
              decoration: const InputDecoration(
                labelText: 'WiFi Password *',
                hintText: 'Enter your WiFi password',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _backendUrlController,
              decoration: const InputDecoration(
                labelText: 'Backend URL *',
                hintText: 'http://your-backend-server.com:3001',
                prefixIcon: Icon(Icons.cloud),
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _brokerUrlController,
              decoration: const InputDecoration(
                labelText: 'MQTT Broker URL *',
                hintText: 'mqtt://your-mqtt-broker.com:1883',
                prefixIcon: Icon(Icons.router),
              ),
            ),
            
            // Device Status Display
            if (_lastDeviceStatus != null) ...[
              const SizedBox(height: 20),
              _buildDeviceStatusCard(),
            ],
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProvisioning || !bluetooth.isConnected 
                        ? null 
                        : () => _sendProvisioningData(bluetooth),
                    icon: _isProvisioning 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isProvisioning ? 'Provisioning...' : 'Send Configuration'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => setState(() => _showProvisioningForm = false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectToDevice(BluetoothDevice device, IoTBluetoothService bluetooth) async {
    try {
      // Clear previous status when connecting to new device
      setState(() {
        _lastDeviceStatus = null;
      });
      
      await bluetooth.connectToDevice(device);
      setState(() {
        _selectedDevice = device;
      });
      
      // Wait a moment for service discovery to complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check if we found the correct characteristic
      if (bluetooth.isConnected) {
        setState(() {
          _showProvisioningForm = true;
          // Pre-fill device name with connected device name or ID
          _deviceNameController.text = device.name.isNotEmpty 
              ? device.name 
              : 'Device_${device.id.toString().substring(0, 8)}';
          
          // Pre-fill URLs with defaults if empty
          if (_backendUrlController.text.trim().isEmpty) {
            _backendUrlController.text = 'http://192.168.1.100:3001';
          }
          if (_brokerUrlController.text.trim().isEmpty) {
            _brokerUrlController.text = 'mqtt://192.168.1.100:1883';
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${device.name.isNotEmpty ? device.name : device.id.toString()}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to establish proper connection');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendProvisioningData(IoTBluetoothService bluetooth) async {
    if (_deviceNameController.text.trim().isEmpty ||
        _ssidController.text.trim().isEmpty || 
        _wifiPasswordController.text.trim().isEmpty ||
        _backendUrlController.text.trim().isEmpty ||
        _brokerUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    
    setState(() => _isProvisioning = true);

    try {
      final config = ProvisioningConfig(
        deviceName: _deviceNameController.text.trim(),
        ssid: _ssidController.text.trim(),
        wifiPassword: _wifiPasswordController.text.trim(),
        userUuid: auth.uuid ?? '',
        userPassword: '', // This would typically come from auth
        backendUrl: _backendUrlController.text.trim(),
        brokerUrl: _brokerUrlController.text.trim(),
      );

      await bluetooth.sendProvisioningData(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Provisioning data sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear form but keep it visible for potential WiFi changes
        // _clearForm(); // Don't clear form in case user wants to retry with different WiFi
        // Keep form open in case device fails to connect and user needs to change WiFi
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Provisioning failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProvisioning = false);
      }
    }
  }

  List<BluetoothDevice> _getFilteredDevices(IoTBluetoothService bluetooth) {
    if (_showUnnamedDevices) {
      return bluetooth.discoveredDevices;
    }
    return bluetooth.discoveredDevices.where((device) => device.name.isNotEmpty).toList();
  }

  void _clearForm() {
    _deviceNameController.clear();
    _ssidController.clear();
    _wifiPasswordController.clear();
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _ssidController.dispose();
    _wifiPasswordController.dispose();
    _backendUrlController.dispose();
    _brokerUrlController.dispose();
    super.dispose();
  }

  Widget _buildDeviceStatusCard() {
    if (_lastDeviceStatus == null) return const SizedBox.shrink();
    
    final status = _lastDeviceStatus!;
    
    return Card(
      color: status.errorMessage != null 
          ? Colors.red.withOpacity(0.1)
          : status.isFullyProvisioned
              ? Colors.green.withOpacity(0.1)
              : Colors.blue.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status.errorMessage != null
                      ? Icons.error
                      : status.isFullyProvisioned
                          ? Icons.check_circle
                          : Icons.info,
                  color: status.errorMessage != null
                      ? Colors.red
                      : status.isFullyProvisioned
                          ? Colors.green
                          : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Device Status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  status.timestamp.toLocal().toString().split('.').first,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (status.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Error: ${status.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            
            _buildStatusIndicator('WiFi Connection', status.isWifiConnected, status.wifiSsid),
            const SizedBox(height: 4),
            _buildStatusIndicator('MQTT Connection', status.isMqttConnected, status.mqttBrokerUrl),
            const SizedBox(height: 4),
            _buildStatusIndicator('Device Registration', status.isRegistered, null),
            
            if (status.isFullyProvisioned)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '\u2713 Device is fully provisioned and ready!',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusIndicator(String label, bool isSuccess, String? details) {
    return Row(
      children: [
        Icon(
          isSuccess ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isSuccess ? Colors.green : Colors.grey,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: isSuccess ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                if (details != null && isSuccess)
                  TextSpan(
                    text: ' ($details)',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
