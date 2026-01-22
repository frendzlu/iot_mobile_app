import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../logging/log_service.dart';
import '../../models/provisioning_config.dart';
import '../../models/sensor_data.dart';
import '../../models/log_entry.dart' as models;

class IoTBluetoothService extends ChangeNotifier {
  static final IoTBluetoothService _instance = IoTBluetoothService._internal();
  factory IoTBluetoothService() => _instance;
  IoTBluetoothService._internal() {
    _initializeService();
  }

  final LogService _logService = LogService();
  
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  
  final List<BluetoothDevice> _discoveredDevices = [];
  bool _isScanning = false;
  bool _isConnected = false;
  bool _showUnnamedDevicesInLogs = false;
  
  final StreamController<SensorData> _sensorDataController = StreamController<SensorData>.broadcast();
  StreamSubscription? _characteristicSubscription;

  // Getters
  List<BluetoothDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;

  // Setters
  set showUnnamedDevicesInLogs(bool value) {
    _showUnnamedDevicesInLogs = value;
  }

  void _initializeService() {
    _logService.info('BLE', 'Bluetooth service initialized');
  }

  void _log(String message, {models.LogLevel level = models.LogLevel.info}) {
    _logService.log('BLE', message, level: level);
  }

  /// Requests all necessary permissions for BLE scanning and connecting
  Future<void> requestPermissions() async {
    if (!Platform.isAndroid) return;

    final List<Permission> permissions = [];

    if (Platform.isAndroid && (await _androidVersion() >= 31)) {
      permissions.addAll([
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ]);
    } else {
      permissions.add(Permission.location);
    }

    for (final permission in permissions) {
      if (!await permission.isGranted) {
        final result = await permission.request();
        if (!result.isGranted) {
          _log('Permission denied: $permission', level: models.LogLevel.error);
          throw Exception('Required permission denied: $permission');
        }
      }
    }
    _log('All required permissions granted', level: models.LogLevel.success);
  }

  Future<int> _androidVersion() async {
    if (!Platform.isAndroid) return 0;
    try {
      // This is a simplified approach - in a real app you might use device_info_plus
      return 31; // Assume modern Android for simplicity
    } catch (e) {
      return 0;
    }
  }

  /// Scan for nearby Bluetooth devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isScanning) return;

    _log('Starting BLE scan...');
    _isScanning = true;
    _discoveredDevices.clear();
    notifyListeners();

    try {
      await requestPermissions();

      // Listen to scan results
      final scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          if (!_discoveredDevices.any((d) => d.id == result.device.id)) {
            _discoveredDevices.add(result.device);
            // Only log named devices if filter is enabled
            if (_showUnnamedDevicesInLogs || result.device.name.isNotEmpty) {
              _log('Found device: ${result.device.name.isNotEmpty ? result.device.name : result.device.id.toString()}');
            }
          }
        }
        notifyListeners();
      });

      await FlutterBluePlus.startScan(timeout: timeout);
      
      // Wait for scan to complete
      await Future.delayed(timeout);
      await scanSubscription.cancel();

      _log('Scan completed. Found ${_discoveredDevices.length} devices', level: models.LogLevel.success);
    } catch (e) {
      _log('Scan failed: $e', level: models.LogLevel.error);
      rethrow;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Connect to a specific device
  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_isConnected && _connectedDevice?.id == device.id) {
      _log('Already connected to ${device.name}');
      return;
    }

    await disconnect();

    _log('Connecting to ${device.name.isNotEmpty ? device.name : device.id.toString()}...');

    try {
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
        mtu: null,
        license: License.free,
      );
      _connectedDevice = device;
      _isConnected = true;

      _log('Connected successfully', level: models.LogLevel.success);
      
      // Discover services and characteristics
      await _discoverServicesAndCharacteristics();
      
      notifyListeners();
    } catch (e) {
      _log('Connection failed: $e', level: models.LogLevel.error);
      _isConnected = false;
      _connectedDevice = null;
      notifyListeners();
      rethrow;
    }
  }

  /// Discover services and characteristics
  Future<void> _discoverServicesAndCharacteristics() async {
    if (_connectedDevice == null) return;

    _log('Discovering services...');
    final services = await _connectedDevice!.discoverServices();

    // Look for our specific service UUID (0x1816)
    const String targetServiceUuid = "1816";
    const String targetCharUuid = "2a01";

    for (final service in services) {
      _log('Found service: ${service.uuid}');
      
      // Check if this is our target service
      if (service.uuid.toString().toLowerCase() == targetServiceUuid.toLowerCase()) {
        _log('Found target WiFi service!', level: models.LogLevel.success);
        
        for (final characteristic in service.characteristics) {
          _log('Found characteristic: ${characteristic.uuid} - ${characteristic.properties}');
          
          // Find our specific write characteristic for provisioning
          if (characteristic.uuid.toString().toLowerCase() == targetCharUuid.toLowerCase() &&
              characteristic.properties.write) {
            _writeCharacteristic = characteristic;
            _log('Set WiFi provisioning characteristic: ${characteristic.uuid}', level: models.LogLevel.success);
          }
        }
      } else {
        // For other services, find notify characteristics for sensor data
        for (final characteristic in service.characteristics) {
          _log('Found characteristic: ${characteristic.uuid} - ${characteristic.properties}');
          
          // Find notify characteristic for sensor data
          if (characteristic.properties.notify && _notifyCharacteristic == null) {
            _notifyCharacteristic = characteristic;
            _log('Set notify characteristic: ${characteristic.uuid}', level: models.LogLevel.success);
            
            // Subscribe to notifications
            await _subscribeToNotifications();
          }
        }
      }
    }
  }

  /// Subscribe to characteristic notifications for sensor data
  Future<void> _subscribeToNotifications() async {
    if (_notifyCharacteristic == null) return;

    try {
      await _notifyCharacteristic!.setNotifyValue(true);
      _characteristicSubscription = _notifyCharacteristic!.value.listen((value) {
        _handleSensorData(value);
      });
      _log('Subscribed to sensor data notifications', level: models.LogLevel.success);
    } catch (e) {
      _log('Failed to subscribe to notifications: $e', level: models.LogLevel.error);
    }
  }

  /// Handle incoming sensor data
  void _handleSensorData(List<int> data) {
    try {
      final jsonString = utf8.decode(data);
      final jsonData = jsonDecode(jsonString);
      
      final sensorData = SensorData.fromJson(jsonData);
      _sensorDataController.add(sensorData);
      
      _log('Received sensor data: ${sensorData.sensor} = ${sensorData.value}${sensorData.unit ?? ''}');
    } catch (e) {
      _log('Failed to parse sensor data: $e', level: models.LogLevel.error);
    }
  }

  /// Send provisioning data to the connected device
  Future<void> sendProvisioningData(ProvisioningConfig config) async {
    if (_writeCharacteristic == null) {
      throw Exception('No WiFi provisioning characteristic available. Make sure you are connected to the correct device.');
    }

    _log('Sending provisioning data...');

    try {
      final jsonData = jsonEncode(config.toJson());
      final payload = utf8.encode(jsonData);
      
      _log('Sending JSON: $jsonData');
      _log('Payload size: ${payload.length} bytes');
      
      // Try to negotiate a larger MTU first
      try {
        final mtu = await _connectedDevice!.requestMtu(247); // Max MTU for most devices
        _log('MTU negotiated: $mtu bytes');
      } catch (e) {
        _log('MTU negotiation failed, using default: $e', level: models.LogLevel.warning);
      }
      
      // Check if we need to chunk the data
      const int maxChunkSize = 200; // Safe chunk size for most BLE implementations
      
      if (payload.length <= maxChunkSize) {
        // Single write
        await _writeCharacteristic!.write(payload, withoutResponse: false);
      } else {
        // Chunked write
        _log('Data too large, sending in chunks...');
        
        for (int i = 0; i < payload.length; i += maxChunkSize) {
          final endIndex = (i + maxChunkSize < payload.length) ? i + maxChunkSize : payload.length;
          final chunk = payload.sublist(i, endIndex);
          
          _log('Sending chunk ${(i ~/ maxChunkSize) + 1}/${((payload.length - 1) ~/ maxChunkSize) + 1} (${chunk.length} bytes)');
          
          await _writeCharacteristic!.write(chunk, withoutResponse: false);
          
          // Small delay between chunks
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      
      _log('Provisioning data sent successfully', level: models.LogLevel.success);
    } catch (e) {
      _log('Failed to send provisioning data: $e', level: models.LogLevel.error);
      rethrow;
    }
  }

  /// Set custom WiFi provisioning characteristic
  void setWifiProvisioningCharacteristic(BluetoothCharacteristic characteristic) {
    _writeCharacteristic = characteristic;
    _log('Manually set WiFi provisioning characteristic: ${characteristic.uuid}', level: models.LogLevel.success);
    notifyListeners();
  }

  /// Get current WiFi provisioning characteristic
  BluetoothCharacteristic? get wifiProvisioningCharacteristic => _writeCharacteristic;

  /// Set custom sensor data notify characteristic
  Future<void> setSensorDataCharacteristic(BluetoothCharacteristic characteristic) async {
    // Unsubscribe from previous characteristic if any
    if (_notifyCharacteristic != null) {
      try {
        await _notifyCharacteristic!.setNotifyValue(false);
        await _characteristicSubscription?.cancel();
      } catch (e) {
        _log('Error unsubscribing from previous characteristic: $e', level: models.LogLevel.warning);
      }
    }
    
    _notifyCharacteristic = characteristic;
    _log('Manually set sensor data characteristic: ${characteristic.uuid}', level: models.LogLevel.success);
    
    // Subscribe to the new characteristic
    await _subscribeToNotifications();
    notifyListeners();
  }

  /// Get current sensor data notify characteristic
  BluetoothCharacteristic? get sensorDataCharacteristic => _notifyCharacteristic;

  /// Get detailed services information for device inspection
  Future<List<BluetoothService>?> getServicesInfo() async {
    if (_connectedDevice == null || !_isConnected) return null;
    
    try {
      return await _connectedDevice!.discoverServices();
    } catch (e) {
      _log('Failed to get services info: $e', level: models.LogLevel.error);
      return null;
    }
  }

  /// Disconnect from the current device
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      _log('Disconnecting from ${_connectedDevice!.name}...');
      
      await _characteristicSubscription?.cancel();
      _characteristicSubscription = null;
      
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        _log('Error during disconnect: $e', level: models.LogLevel.warning);
      }
      
      _connectedDevice = null;
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _isConnected = false;
      
      _log('Disconnected', level: models.LogLevel.info);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disconnect();
    _sensorDataController.close();
    super.dispose();
  }
}