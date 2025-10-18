// File: services/bridge_service.dart
// (This file replaces tnc_service.dart)

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:network_info_plus/network_info_plus.dart';

// KISS Protocol Constants
const int FEND = 0xC0; // Frame End
const int FESC = 0xDB; // Frame Escape
const int TFEND = 0xDC; // Transposed Frame End
const int TFESC = 0xDD; // Transposed Frame Escape
// const int KISS_CMD_DATA = 0x00; // Not needed for transparent bridge

/// Hardcoded test KISS frame
/// AX.25: N0CALL>APRS,WIDE1-1:>Test
/// C0 00 82909A9C884060 9C829486849860 A68A8886404063 03 F0 3E54657374 C0
final Uint8List _testKissFrame = Uint8List.fromList([
  0xC0, 0x00, // FEND, CMD_DATA
  0x82, 0x90, 0x9A, 0x9C, 0x88, 0x40, 0x60, // Dest: APRS
  0x9C, 0x82, 0x94, 0x86, 0x84, 0x98, 0x60, // Src: N0CALL
  0xA6, 0x8A, 0x88, 0x86, 0x40, 0x40, 0x63, // Path: WIDE1-1 (last)
  0x03, 0xF0, // Ctrl, PID
  0x3E, 0x54, 0x65, 0x73, 0x74, // Payload: >Test
  0xC0 // FEND
]);

class BridgeService {
  // --- TNC State ---
  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _dataSubscription;
  List<int> _buffer = [];

  // --- TCP Server State ---
  ServerSocket? _serverSocket;
  final List<Socket> _tcpClients = [];
  final int _tcpPort = 8001;
  String? _ipAddress;

  // --- Stream Controllers ---
  final _logController = StreamController<String>.broadcast();
  final _tncConnectionStatusController = StreamController<bool>.broadcast();
  final _deviceListController =
      StreamController<List<BluetoothDevice>>.broadcast();
  final _isScanningController = StreamController<bool>.broadcast();
  final _ipAddressController = StreamController<String?>.broadcast();
  final _tcpStatusController = StreamController<String>.broadcast();

  // --- Public Streams ---
  Stream<String> get logStream => _logController.stream;
  Stream<bool> get isConnectedStream => _tncConnectionStatusController.stream;
  Stream<List<BluetoothDevice>> get deviceStream => _deviceListController.stream;
  Stream<bool> get isScanningStream => _isScanningController.stream;
  Stream<String?> get ipAddressStream => _ipAddressController.stream;
  Stream<String> get tcpStatusStream => _tcpStatusController.stream;

  BridgeService() {
    _tncConnectionStatusController.add(false);
    _isScanningController.add(false);
    _initNetworkInfo();
    _startTcpServer();
  }

  // --- Network & Server Logic ---
  Future<void> _initNetworkInfo() async {
    try {
      _ipAddress = await NetworkInfo().getWifiIP();
      _ipAddressController.add(_ipAddress);
    } catch (e) {
      _logController.add('Error getting IP: $e');
      _ipAddressController.add(null);
    }
  }

  Future<void> _startTcpServer() async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, _tcpPort);
      String status = 'Listening on $_ipAddress:$_tcpPort';
      _tcpStatusController.add(status);
      _logController.add(status);
      _serverSocket!.listen(_onTcpConnection);
    } catch (e) {
      String error = 'Error starting TCP server: $e';
      _tcpStatusController.add('Server Error');
      _logController.add(error);
    }
  }

  void _onTcpConnection(Socket client) {
    String clientAddr = '${client.remoteAddress.address}:${client.remotePort}';
    _logController.add('TCP Client connected: $clientAddr');
    _tcpClients.add(client);
    _updateTcpClientStatus();

    client.listen(
      (data) => _onTcpData(client, data),
      onError: (e) {
        _logController.add('TCP Client error ($clientAddr): $e');
        _removeTcpClient(client);
      },
      onDone: () {
        _logController.add('TCP Client disconnected: $clientAddr');
        _removeTcpClient(client);
      },
    );
  }

  void _removeTcpClient(Socket client) {
    client.close();
    _tcpClients.remove(client);
    _updateTcpClientStatus();
  }

  void _updateTcpClientStatus() {
    if (_tcpClients.isEmpty) {
      _tcpStatusController.add('Listening on $_ipAddress:$_tcpPort');
    } else {
      _tcpStatusController
          .add('Listening (${_tcpClients.length} client(s) connected)');
    }
  }

  /// Data received FROM a TCP client, send TO TNC
  void _onTcpData(Socket client, Uint8List data) {
    if (_connection == null || !_connection!.isConnected) {
      _logController.add('TCP -> TNC: Dropped, TNC not connected.');
      return;
    }
    try {
      _logController.add('TCP -> TNC: ${data.length} bytes');
      _connection!.output.add(data);
    } catch (e) {
      _logController.add('Error writing to TNC: $e');
    }
  }

  /// Data received FROM TNC, send TO all TCP clients
  void _sendToTcpClients(Uint8List fullKissFrame) {
    if (_tcpClients.isEmpty) return; // No one to send to

    _logController.add('TNC -> TCP: ${fullKissFrame.length} bytes');
    for (var client in _tcpClients) {
      try {
        client.add(fullKissFrame);
      } catch (e) {
        _logController
            .add('Error sending to client ${client.remoteAddress.address}: $e');
      }
    }
  }

  void _stopTcpServer() {
    _logController.add('Stopping TCP server...');
    for (var client in _tcpClients) {
      client.close();
    }
    _tcpClients.clear();
    _serverSocket?.close();
    _tcpStatusController.add('Not listening');
  }

  // --- TNC Connection Methods ---
  Future<void> getPairedDevices() async {
    _isScanningController.add(true);
    _logController.add('Scanning for paired devices...');
    try {
      List<BluetoothDevice> devices =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      _deviceListController.add(devices);
      _logController.add('Scan complete. Found ${devices.length} devices.');
    } catch (e) {
      _logController.add('Error scanning: $e');
    } finally {
      _isScanningController.add(false);
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    _logController.add('Connecting to ${device.name ?? device.address}...');
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _tncConnectionStatusController.add(true);
      _logController.add('TNC Connection established successfully.');
      _dataSubscription = _connection!.input!.listen(
        _onDataReceived,
        onDone: () => disconnect(remote: true),
        onError: (e) {
          _logController.add('TNC Stream Error: $e');
          disconnect();
        },
      );
    } catch (e) {
      _logController.add('Error connecting to TNC: $e');
      _tncConnectionStatusController.add(false);
    }
  }

  Future<void> disconnect({bool remote = false}) async {
    if (remote) {
      _logController.add('TNC disconnected remotely.');
    } else {
      _logController.add('Disconnecting from TNC...');
    }
    await _dataSubscription?.cancel();
    await _connection?.close();
    _connection = null;
    _dataSubscription = null;
    _buffer.clear();
    _tncConnectionStatusController.add(false);
    if (!remote) _logController.add('TNC Connection closed.');
  }

  // --- TNC Data Processing and Logic ---

  /// Data received FROM the TNC
  void _onDataReceived(Uint8List data) {
    _buffer.addAll(data);
    _processBuffer();
  }

  /// Finds KISS frames in the buffer and forwards them
  void _processBuffer() {
    while (_buffer.contains(FEND)) {
      int frameStartIndex = _buffer.indexOf(FEND);
      if (frameStartIndex > 0) {
        // Discard data before the first FEND
        _buffer.removeRange(0, frameStartIndex);
      }

      if (_buffer.length < 2) {
        break; // Not enough data for a frame
      }

      // Remove leading FEND
      _buffer.removeAt(0);

      int frameEndIndex = _buffer.indexOf(FEND);
      if (frameEndIndex == -1) {
        // Frame is incomplete, put FEND back and wait for more data
        _buffer.insert(0, FEND);
        break;
      }

      // We have the content of a frame (between FENDs)
      Uint8List frameContent =
          Uint8List.fromList(_buffer.sublist(0, frameEndIndex));

      // Consume the frame content from the buffer
      _buffer.removeRange(0, frameEndIndex);

      if (frameContent.isEmpty) {
        continue; // Skip empty FEND pairs (e.g., FEND FEND)
      }

      // Reconstruct the full KISS frame to send to TCP clients
      Uint8List fullKissFrame =
          Uint8List.fromList([FEND, ...frameContent, FEND]);

      // Forward the full, raw KISS frame
      _sendToTcpClients(fullKissFrame);
    }
  }

  /// Public method to send a test packet TO the TNC
  Future<void> sendTestPacket() async {
    if (_connection == null || !_connection!.isConnected) {
      _logController.add('TX Error: Not connected to TNC.');
      return;
    }

    try {
      _logController.add('USER -> TNC: Sending test packet...');
      _connection!.output.add(_testKissFrame);
      await _connection!.output.allSent;
    } catch (e) {
      _logController.add('Test Packet TX Error: $e');
    }
  }

  void dispose() {
    _logController.close();
    _tncConnectionStatusController.close();
    _deviceListController.close();
    _isScanningController.close();
    _ipAddressController.close();
    _tcpStatusController.close();
    disconnect();
    _stopTcpServer();
  }
}