import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../services/bridge_service.dart';

void main() {
  runApp(const KissBridgeApp());
}

class KissBridgeApp extends StatelessWidget {
  const KissBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KISS-TCP Bridge',
      theme: ThemeData.dark().copyWith(
        useMaterial3: false,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
        ),
      ),
      home: const KissBridgeHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class KissBridgeHomePage extends StatefulWidget {
  const KissBridgeHomePage({super.key});

  @override
  State<KissBridgeHomePage> createState() => _KissBridgeHomePageState();
}

class _KissBridgeHomePageState extends State<KissBridgeHomePage> {
  final BridgeService _bridgeService = BridgeService();
  BluetoothDevice? _selectedDevice;

  // UI-specific state
  final List<String> _logs = [];
  final _logScrollController = ScrollController();
  String _ipAddress = "Loading...";
  String _tcpStatus = "Initializing...";

  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _subscriptions.add(_bridgeService.logStream.listen(_addLog));

    _subscriptions.add(_bridgeService.ipAddressStream.listen((ip) {
      if (mounted) {
        setState(() => _ipAddress = ip ?? "Wi-Fi IP Not Found");
      }
    }));

    _subscriptions.add(_bridgeService.tcpStatusStream.listen((status) {
      if (mounted) {
        setState(() => _tcpStatus = status);
      }
    }));

    _bridgeService.getPairedDevices();
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _bridgeService.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  // --- Stream Listeners ---
  void _addLog(String message) {
    _updateLogs(message);
  }

  void _updateLogs(String entry) {
    if (!mounted) return;
    setState(() {
      _logs.add(entry);
      if (_logs.length > 200) {
        // Prevent infinite log growth
        _logs.removeAt(0);
      }
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- UI Event Handlers ---
  void _onToggleConnection(bool isConnected) {
    if (isConnected) {
      _bridgeService.disconnect();
    } else {
      if (_selectedDevice == null) return;
      _bridgeService.connect(_selectedDevice!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KISS-TCP Bridge'),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildServerStatusCard(),
            const SizedBox(height: 16),
            _buildConnectionCard(),
            const SizedBox(height: 16),
            _buildTestCard(),
            const SizedBox(height: 16),
            _buildLogCard(),
          ],
        ),
      ),
    );
  }

  // --- UI Builder Methods ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: Colors.blueAccent)),
    );
  }

  Widget _buildServerStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('TCP Server'),
            ListTile(
              leading:
                  const Icon(Icons.public, color: Colors.blueAccent, size: 30),
              title: const Text('IP Address'),
              subtitle: Text(_ipAddress,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.settings_remote,
                  color: Colors.blueAccent, size: 30),
              title: const Text('Server Status'),
              subtitle: Text(_tcpStatus,
                  style:
                      const TextStyle(fontSize: 14, color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<bool>(
            stream: _bridgeService.isConnectedStream,
            initialData: false,
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Bluetooth TNC'),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12.0),
                          decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8.0)),
                          child: StreamBuilder<List<BluetoothDevice>>(
                            stream: _bridgeService.deviceStream,
                            initialData: const [],
                            builder: (context, snapshot) {
                              return DropdownButtonHideUnderline(
                                child: DropdownButton<BluetoothDevice>(
                                  value: _selectedDevice,
                                  isExpanded: true,
                                  hint: const Text('Select a Paired TNC'),
                                  dropdownColor: Colors.grey[850],
                                  items: snapshot.data?.map((device) {
                                    return DropdownMenuItem(
                                      value: device,
                                      child:
                                          Text(device.name ?? device.address),
                                    );
                                  }).toList(),
                                  onChanged: isConnected
                                      ? null
                                      : (device) => setState(
                                          () => _selectedDevice = device),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StreamBuilder<bool>(
                        stream: _bridgeService.isScanningStream,
                        initialData: true,
                        builder: (context, snapshot) {
                          final isScanning = snapshot.data ?? false;
                          return isScanning
                              ? const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator()))
                              : IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: isConnected
                                      ? null
                                      : _bridgeService.getPairedDevices,
                                  tooltip: 'Scan for Paired Devices',
                                );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                  color: isConnected
                                      ? Colors.greenAccent.shade400
                                      : Colors.redAccent.shade400,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(isConnected ? 'Connected' : 'Disconnected',
                              style: TextStyle(
                                  color: isConnected
                                      ? Colors.greenAccent.shade400
                                      : Colors.redAccent.shade400,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      // NOTE:
                      // ElevatedButton.icon does NOT accept a `tooltip:` named parameter.
                      // If you want a tooltip for the button, wrap it with Tooltip(...).
                      ElevatedButton.icon(
                        onPressed: (_selectedDevice == null && !isConnected)
                            ? null
                            : () => _onToggleConnection(isConnected),
                        icon: Icon(isConnected
                            ? Icons.bluetooth_disabled
                            : Icons.bluetooth_connected),
                        label: Text(isConnected ? 'Disconnect' : 'Connect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isConnected
                              ? Colors.redAccent.shade400
                              : Colors.blueAccent.shade400,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
      ),
    );
  }

  Widget _buildTestCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<bool>(
            stream: _bridgeService.isConnectedStream,
            initialData: false,
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;
              return Center(
                //
                // THIS CODE IS NOW CORRECT.
                // IT HAS NO TOOLTIP PARAMETER.
                //
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send Test Packet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  onPressed: isConnected ? _bridgeService.sendTestPacket : null,
                ),
                //
                //
                //
              );
            }),
      ),
    );
  }

  Widget _buildLogCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Activity Log'),
            Container(
              height: 300,
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8.0)),
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                controller: _logScrollController,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  Color textColor = Colors.white70; // System default

                  if (log.startsWith('TNC -> TCP')) {
                    textColor = Colors.lightGreenAccent.shade400; // From Radio
                  } else if (log.startsWith('TCP -> TNC')) {
                    textColor = Colors.cyanAccent.shade400; // To Radio
                  } else if (log.startsWith('USER -> TNC')) {
                    textColor = Colors.orangeAccent.shade400; // Test packet
                  } else if (log.startsWith('Error') ||
                      log.startsWith('TCP Client error')) {
                    textColor = Colors.redAccent.shade200;
                  }

                  final timestamp =
                      DateTime.now().toIso8601String().substring(11, 23);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                        children: [
                          TextSpan(
                            text: '[$timestamp] ',
                            style: const TextStyle(color: Colors.white38),
                          ),
                          TextSpan(
                            text: log,
                            style: TextStyle(color: textColor),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}