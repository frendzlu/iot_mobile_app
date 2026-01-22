import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/ble/bluetooth_service.dart';

class DeviceInspectorTab extends StatefulWidget {
  const DeviceInspectorTab({super.key});

  @override
  State<DeviceInspectorTab> createState() => _DeviceInspectorTabState();
}

class _DeviceInspectorTabState extends State<DeviceInspectorTab> {
  List<BluetoothService>? _services;
  bool _isLoading = false;
  BluetoothCharacteristic? _selectedWifiCharacteristic;
  BluetoothCharacteristic? _selectedSensorCharacteristic;

  @override
  void initState() {
    super.initState();
    // Don't call _loadServices() here as context.read may not be available
  }

  Future<void> _loadServices() async {
    if (!mounted) return;
    
    final bluetooth = context.read<IoTBluetoothService>();
    if (!bluetooth.isConnected) {
      print('DeviceInspector: Device not connected, skipping service load');
      return;
    }
    
    print('DeviceInspector: Starting to load services...');
    setState(() => _isLoading = true);
    
    try {
      final services = await bluetooth.getServicesInfo();
      print('DeviceInspector: Loaded ${services?.length ?? 0} services');
      
      if (mounted) {
        setState(() {
          _services = services;
          _isLoading = false;
        });
        print('DeviceInspector: UI updated with ${_services?.length ?? 0} services');
      }
    } catch (e) {
      print('DeviceInspector: Error loading services: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load services: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Inspector'),
        actions: [
          Consumer<IoTBluetoothService>(
            builder: (context, bluetooth, _) {
              if (bluetooth.isConnected) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadServices,
                  tooltip: 'Refresh',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<IoTBluetoothService>(
        builder: (context, bluetooth, _) {
          // Load services when connected and not already loaded
          if (bluetooth.isConnected && _services == null && !_isLoading) {
            print('DeviceInspector: Triggering service load via addPostFrameCallback');
            WidgetsBinding.instance.addPostFrameCallback((_) => _loadServices());
          }
          
          // Update selected characteristics to match current characteristics
          if (_selectedWifiCharacteristic?.uuid != bluetooth.wifiProvisioningCharacteristic?.uuid) {
            _selectedWifiCharacteristic = bluetooth.wifiProvisioningCharacteristic;
          }
          if (_selectedSensorCharacteristic?.uuid != bluetooth.sensorDataCharacteristic?.uuid) {
            _selectedSensorCharacteristic = bluetooth.sensorDataCharacteristic;
          }
          
          if (!bluetooth.isConnected) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bluetooth_disabled,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No device connected',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Connect to a device to inspect its services and characteristics',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          if (_isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading device services...'),
                ],
              ),
            );
          }

          if (_services == null || _services!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.orange,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No services found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connected Device',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text('Name: ${bluetooth.connectedDevice?.name ?? 'Unknown'}'),
                        Text('ID: ${bluetooth.connectedDevice?.id.toString() ?? 'Unknown'}'),
                        Text('Services: ${_services!.length}'),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Services List
                Text(
                  'Services & Characteristics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                
                ...(_services!.map((service) => _buildServiceCard(service)).toList()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildServiceCard(BluetoothService service) {
    final bluetooth = context.read<IoTBluetoothService>();
    final isWifiService = service.characteristics.any(
      (char) => bluetooth.wifiProvisioningCharacteristic?.uuid == char.uuid
    );
    final isSensorService = service.characteristics.any(
      (char) => bluetooth.sensorDataCharacteristic?.uuid == char.uuid
    );
    
    Color? backgroundColor;
    List<Widget> icons = [const Icon(Icons.settings_bluetooth)];
    
    if (isWifiService && isSensorService) {
      backgroundColor = Colors.blue.withOpacity(0.15);
      icons.addAll([
        const SizedBox(width: 4),
        const Icon(Icons.wifi, size: 16, color: Colors.green),
        const Icon(Icons.sensors, size: 16, color: Colors.orange),
      ]);
    } else if (isWifiService) {
      backgroundColor = Colors.green.withOpacity(0.15);
      icons.addAll([
        const SizedBox(width: 4),
        const Icon(Icons.wifi, size: 16, color: Colors.green),
      ]);
    } else if (isSensorService) {
      backgroundColor = Colors.orange.withOpacity(0.15);
      icons.addAll([
        const SizedBox(width: 4),
        const Icon(Icons.sensors, size: 16, color: Colors.orange),
      ]);
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: backgroundColor,
      child: ExpansionTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: icons,
        ),
        title: Text(
          'Service: ${_getServiceName(service.uuid.toString())}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'UUID: ${service.uuid.toString()}\n'
          'Characteristics: ${service.characteristics.length}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Text(
                  'Service Details:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildInfoRow('UUID', service.uuid.toString()),
                _buildInfoRow('Type', service.isPrimary ? 'Primary' : 'Secondary'),
                _buildInfoRow('Characteristics Count', '${service.characteristics.length}'),
                
                const SizedBox(height: 16),
                
                if (service.characteristics.isNotEmpty) ...[
                  Text(
                    'Characteristics:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...service.characteristics.map((char) => _buildCharacteristicTile(char)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacteristicTile(BluetoothCharacteristic characteristic) {
    final bluetooth = context.read<IoTBluetoothService>();
    final isCurrentWifiChar = bluetooth.wifiProvisioningCharacteristic?.uuid == characteristic.uuid;
    final isCurrentSensorChar = bluetooth.sensorDataCharacteristic?.uuid == characteristic.uuid;
    final isSelected = _selectedWifiCharacteristic?.uuid == characteristic.uuid ||
                      _selectedSensorCharacteristic?.uuid == characteristic.uuid;
    
    Color? backgroundColor;
    if (isCurrentWifiChar) {
      backgroundColor = Colors.green.withOpacity(0.2);
    } else if (isCurrentSensorChar) {
      backgroundColor = Colors.orange.withOpacity(0.2);
    } else if (isSelected) {
      backgroundColor = Colors.blue.withOpacity(0.2);
    }
    
    return Card(
      color: backgroundColor,
      child: ExpansionTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.memory, size: 20),
            const SizedBox(width: 4),
            if (isCurrentWifiChar) 
              const Icon(Icons.wifi, size: 16, color: Colors.green),
            if (isCurrentSensorChar)
              const Icon(Icons.sensors, size: 16, color: Colors.orange),
          ],
        ),
        title: Text(
          'Char: ${_getCharacteristicName(characteristic.uuid.toString())}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'UUID: ${characteristic.uuid.toString()}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: _buildCharacteristicButtons(characteristic, isCurrentWifiChar, isCurrentSensorChar),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('UUID', characteristic.uuid.toString()),
                _buildInfoRow('Properties', _formatProperties(characteristic.properties)),
                
                if (characteristic.descriptors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Descriptors (${characteristic.descriptors.length}):',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  ...characteristic.descriptors.map((desc) => 
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Text(
                        '• ${desc.uuid}',
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildCharacteristicButtons(BluetoothCharacteristic characteristic, bool isCurrentWifiChar, bool isCurrentSensorChar) {
    final hasWrite = characteristic.properties.write;
    final hasNotify = characteristic.properties.notify;
    final hasRead = characteristic.properties.read;
    
    if (!hasWrite && !hasNotify && !hasRead) return null;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasWrite)
          ElevatedButton(
            onPressed: () => _selectAsWifiCharacteristic(characteristic),
            child: Text(isCurrentWifiChar ? 'WiFi Current' : 'Use for WiFi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentWifiChar ? Colors.green : Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              textStyle: const TextStyle(fontSize: 10),
            ),
          ),
        if (hasWrite && (hasNotify || hasRead)) const SizedBox(height: 4),
        if (hasNotify || hasRead)
          ElevatedButton(
            onPressed: () => _selectAsSensorCharacteristic(characteristic),
            child: Text(isCurrentSensorChar ? 'Sensor Current' : 'Use for Sensor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentSensorChar ? Colors.orange : Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              textStyle: const TextStyle(fontSize: 10),
            ),
          ),
      ],
    );
  }

  void _selectAsWifiCharacteristic(BluetoothCharacteristic characteristic) {
    final bluetooth = context.read<IoTBluetoothService>();
    bluetooth.setWifiProvisioningCharacteristic(characteristic);
    
    setState(() {
      _selectedWifiCharacteristic = characteristic;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'WiFi provisioning characteristic set to: ${_getCharacteristicName(characteristic.uuid.toString())}',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _selectAsSensorCharacteristic(BluetoothCharacteristic characteristic) async {
    final bluetooth = context.read<IoTBluetoothService>();
    await bluetooth.setSensorDataCharacteristic(characteristic);
    
    setState(() {
      _selectedSensorCharacteristic = characteristic;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sensor data characteristic set to: ${_getCharacteristicName(characteristic.uuid.toString())}',
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  String _formatProperties(CharacteristicProperties properties) {
    final props = <String>[];
    if (properties.read) props.add('Read');
    if (properties.write) props.add('Write');
    if (properties.writeWithoutResponse) props.add('WriteNoResp');
    if (properties.notify) props.add('Notify');
    if (properties.indicate) props.add('Indicate');
    if (properties.authenticatedSignedWrites) props.add('AuthWrite');
    if (properties.extendedProperties) props.add('Extended');
    if (properties.notifyEncryptionRequired) props.add('NotifyEnc');
    if (properties.indicateEncryptionRequired) props.add('IndicateEnc');
    
    return props.isEmpty ? 'None' : props.join(', ');
  }

  String _getServiceName(String uuid) {
    // Common BLE service UUIDs
    const Map<String, String> serviceNames = {
      '1800': 'Generic Access',
      '1801': 'Generic Attribute', 
      '1802': 'Immediate Alert',
      '1803': 'Link Loss',
      '1804': 'Tx Power',
      '1805': 'Current Time',
      '1806': 'Reference Time Update',
      '1807': 'Next DST Change',
      '1808': 'Glucose',
      '1809': 'Health Thermometer',
      '180a': 'Device Information',
      '180d': 'Heart Rate',
      '180e': 'Phone Alert Status',
      '180f': 'Battery',
      '1810': 'Blood Pressure',
      '1811': 'Alert Notification',
      '1812': 'Human Interface Device',
      '1813': 'Scan Parameters',
      '1814': 'Running Speed and Cadence',
      '1815': 'Automation IO',
      '1816': 'Cycling Speed and Cadence',
      '1818': 'Cycling Power',
      '1819': 'Location and Navigation',
      '181a': 'Environmental Sensing',
      '181b': 'Body Composition',
      '181c': 'User Data',
      '181d': 'Weight Scale',
    };
    
    final shortUuid = uuid.toLowerCase().replaceAll('-', '').substring(0, 4);
    return serviceNames[shortUuid] ?? 'Custom Service';
  }

  String _getCharacteristicName(String uuid) {
    // Common BLE characteristic UUIDs
    const Map<String, String> characteristicNames = {
      '2a00': 'Device Name',
      '2a01': 'Appearance',
      '2a02': 'Peripheral Privacy Flag',
      '2a03': 'Reconnection Address',
      '2a04': 'Peripheral Preferred Connection Parameters',
      '2a05': 'Service Changed',
      '2a06': 'Alert Level',
      '2a07': 'Tx Power Level',
      '2a08': 'Date Time',
      '2a09': 'Day of Week',
      '2a0a': 'Day Date Time',
      '2a0c': 'Exact Time 256',
      '2a0d': 'DST Offset',
      '2a0e': 'Time Zone',
      '2a0f': 'Local Time Information',
      '2a11': 'Time with DST',
      '2a12': 'Time Accuracy',
      '2a13': 'Time Source',
      '2a14': 'Reference Time Information',
      '2a16': 'Time Update Control Point',
      '2a17': 'Time Update State',
      '2a18': 'Glucose Measurement',
      '2a19': 'Battery Level',
      '2a1c': 'Temperature Measurement',
      '2a1d': 'Temperature Type',
      '2a1e': 'Intermediate Temperature',
      '2a21': 'Measurement Interval',
      '2a22': 'Boot Keyboard Input Report',
      '2a23': 'System ID',
      '2a24': 'Model Number String',
      '2a25': 'Serial Number String',
      '2a26': 'Firmware Revision String',
      '2a27': 'Hardware Revision String',
      '2a28': 'Software Revision String',
      '2a29': 'Manufacturer Name String',
      '2a2a': 'IEEE 11073-20601 Regulatory',
      '2a35': 'Blood Pressure Measurement',
      '2a36': 'Intermediate Cuff Pressure',
      '2a37': 'Heart Rate Measurement',
      '2a38': 'Body Sensor Location',
      '2a39': 'Heart Rate Control Point',
      '2a3f': 'Alert Status',
      '2a40': 'Ringer Control Point',
      '2a41': 'Ringer Setting',
      '2a42': 'Alert Category ID Bit Mask',
      '2a43': 'Alert Category ID',
      '2a44': 'Alert Notification Control Point',
      '2a45': 'Unread Alert Status',
      '2a46': 'New Alert',
      '2a47': 'Supported New Alert Category',
      '2a48': 'Supported Unread Alert Category',
      '2a4a': 'HID Information',
      '2a4b': 'Report Map',
      '2a4c': 'HID Control Point',
      '2a4d': 'Report',
      '2a4e': 'Protocol Mode',
      '2a4f': 'Scan Interval Window',
      '2a50': 'PnP ID',
      '2a51': 'Glucose Feature',
      '2a52': 'Glucose Measurement Context',
      '2a53': 'Blood Pressure Feature',
      '2a54': 'HID Information',
      '2a55': 'Scan Refresh',
      '2a5b': 'CSC Measurement',
      '2a5c': 'CSC Feature',
      '2a5d': 'Sensor Location',
    };
    
    final shortUuid = uuid.toLowerCase().replaceAll('-', '').substring(0, 4);
    return characteristicNames[shortUuid] ?? 'Custom Characteristic';
  }
}