import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/io.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';

void main() {
  runApp(const AxonApp());
}

class AxonApp extends StatelessWidget {
  const AxonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        primaryColor: const Color(0xFF00E5FF),
      ),
      home: const SatelliteControl(),
    );
  }
}

class SatelliteControl extends StatefulWidget {
  const SatelliteControl({super.key});

  @override
  State<SatelliteControl> createState() => _SatelliteControlState();
}

class _SatelliteControlState extends State<SatelliteControl> {
  // CONFIGURATION: REPLACE THIS WITH YOUR PC'S LOCAL IP ADDRESS
  final String _coreUrl = 'ws://192.168.1.7:8000/axon-link';

  IOWebSocketChannel? _channel;
  bool _isConnected = false;
  String _statusLog = "SYSTEM INITIALIZED...";

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.camera].request();
    _log("Sensors authorized.");
  }

  void _connectToCore() {
    try {
      _log("Attempting Uplink to Core...");
      _channel = IOWebSocketChannel.connect(_coreUrl);

      _channel!.stream.listen(
        (message) {
          // We received audio or data from Python
          _log("Packet Received from Core");
        },
        onError: (error) {
          _log("Uplink Error: $error");
          setState(() => _isConnected = false);
        },
        onDone: () {
          _log("Uplink Severed.");
          setState(() => _isConnected = false);
        },
      );

      setState(() => _isConnected = true);
      _log("UPLINK ESTABLISHED.");
    } catch (e) {
      _log("Connection Failed: $e");
    }
  }

  void _disconnect() {
    _channel?.sink.close();
    setState(() => _isConnected = false);
    _log("Uplink Deactivated.");
  }

  void _log(String msg) {
    setState(() {
      _statusLog = "$msg\n$_statusLog";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "AXON SATELLITE",
                    style: GoogleFonts.orbitron(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Icon(
                        Icons.circle,
                        color:
                            _isConnected
                                ? Colors.greenAccent
                                : Colors.redAccent,
                        size: 12,
                      )
                      .animate(target: _isConnected ? 1 : 0)
                      .boxShadow(
                        end: BoxShadow(
                          color: Colors.greenAccent,
                          blurRadius: 10,
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "ID: IPHONE-14-PRO // GATEWAY",
                style: GoogleFonts.robotoMono(color: Colors.grey, fontSize: 12),
              ),

              const SizedBox(height: 40),

              // CENTRAL STATUS
              Expanded(
                child: Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            _isConnected
                                ? Colors.cyanAccent
                                : Colors.grey.shade800,
                        width: 2,
                      ),
                      boxShadow:
                          _isConnected
                              ? [
                                BoxShadow(
                                  color: Colors.cyanAccent.withOpacity(0.2),
                                  blurRadius: 30,
                                ),
                              ]
                              : [],
                    ),
                    child: MaterialButton(
                      shape: const CircleBorder(),
                      onPressed: _isConnected ? _disconnect : _connectToCore,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isConnected
                                ? Icons.power_settings_new
                                : Icons.link,
                            size: 40,
                            color:
                                _isConnected ? Colors.cyanAccent : Colors.white,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isConnected ? "DISCONNECT" : "CONNECT\nTO CORE",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.orbitron(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // LOGS
              Container(
                height: 150,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    _statusLog,
                    style: GoogleFonts.firaCode(
                      fontSize: 10,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
