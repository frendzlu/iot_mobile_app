import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/ble/bluetooth_service.dart';
import '../../models/provisioning_config.dart';
import '../auth/auth_provider.dart';

class SetupDeviceTab extends StatefulWidget {
  const SetupDeviceTab({super.key});

  @override
  State<SetupDeviceTab> createState() => _SetupDeviceTabState();
}

class _SetupDeviceTabState extends State<SetupDeviceTab> {
  BluetoothDevice? _selectedDevice;
  
  // Provisioning form controllers
  final _ssidController = TextEditingController();
  final _wifiPasswordController = TextEditingController();
  final _customField1Controller = TextEditingController();
  final _customField2Controller = TextEditingController();

  bool _showProvisioningForm = false;
  bool _isProvisioning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          return Padding(
            padding: const EdgeInsets.all(16),
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
            
            // Device List
            if (bluetooth.discoveredDevices.isNotEmpty)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: bluetooth.discoveredDevices.length,
                  itemBuilder: (context, index) {
                    final device = bluetooth.discoveredDevices[index];
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
              controller: _customField1Controller,
              decoration: const InputDecoration(
                labelText: 'Custom Field 1',
                hintText: 'Optional custom parameter',
                prefixIcon: Icon(Icons.settings),
              ),
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: _customField2Controller,
              decoration: const InputDecoration(
                labelText: 'Custom Field 2',
                hintText: 'Optional custom parameter',
                prefixIcon: Icon(Icons.settings),
              ),
            ),
            
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
      await bluetooth.connectToDevice(device);
      setState(() {
        _selectedDevice = device;
        _showProvisioningForm = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device.name.isNotEmpty ? device.name : device.id.toString()}'),
            backgroundColor: Colors.green,
          ),
        );
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
    if (_ssidController.text.trim().isEmpty || _wifiPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in WiFi SSID and Password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    
    setState(() => _isProvisioning = true);

    try {
      final config = ProvisioningConfig(
        deviceName: _selectedDevice?.name ?? _selectedDevice!.id.toString(),
        ssid: _ssidController.text.trim(),
        wifiPassword: _wifiPasswordController.text.trim(),
        userUuid: auth.uuid ?? '',
        userPassword: '', // This would typically come from auth
        backendUrl: auth.backendUrl ?? '',
        customField1: _customField1Controller.text.trim(),
        customField2: _customField2Controller.text.trim(),
      );

      await bluetooth.sendProvisioningData(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Provisioning data sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear form and hide it
        _clearForm();
        setState(() => _showProvisioningForm = false);
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

  void _clearForm() {
    _ssidController.clear();
    _wifiPasswordController.clear();
    _customField1Controller.clear();
    _customField2Controller.clear();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _wifiPasswordController.dispose();
    _customField1Controller.dispose();
    _customField2Controller.dispose();
    super.dispose();
  }
}
