import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:yeedart/src/command/command.dart';
import 'package:yeedart/src/response/command_response.dart';
import 'package:yeedart/src/exception/exception.dart';
import 'package:yeedart/src/command/command_sender.dart';

/// Implementation of [CommandSender]
class TCPCommandSender implements CommandSender {
  final InternetAddress address;
  final int port;

  @visibleForTesting
  Socket socket;

  Stream<Uint8List> _socketStream = const Stream.empty();

  bool _connected = false;

  TCPCommandSender({@required this.address, @required this.port});

  @override
  bool get isConnected => _connected;

  @override
  Stream<Uint8List> get connectionStream => _socketStream.asBroadcastStream();

  @override
  Future<CommandResponse> sendCommand(Command command) async {
    CommandResponse response;

    if (!_connected) {
      await _connect();
    }
    // print(command);

    socket.add(utf8.encode(command.message));

    await for (final data in _socketStream) {
      final res = utf8.decode(data);
      Map<String, dynamic> jsonMap;

      final lines = res.split('\r\n')
          .where((r) => r.isNotEmpty)
          .toList(growable: false);
      // If there are more than 2 lines, the lamp also sent an ack object
      if (lines.length == 2) {
        jsonMap = json.decode(lines.first)
          as Map<String, dynamic>;
        jsonMap['ackVal'] = json.decode(lines[1])['params'];
      } else {
        jsonMap = json.decode(res) as Map<String, dynamic>;
      }
      // print(jsonMap);
      response = CommandResponse.fromJson(jsonMap);
      break;
    }

    return response;
  }

  /// Creates TCP connection to [address] and [port].
  Future<void> _connect() async {
    try {
      socket = await Socket.connect(address, port);
      _socketStream = socket.asBroadcastStream();
      _connected = true;
      //print('Connected to ${address.address}:$port');
    } on SocketException catch (e) {
      String additionalInfo;
      if (e.osError.errorCode == 1225) {
        additionalInfo = ' Make sure that LAN control is enabled.';
      }
      throw YeelightConnectionException('${e.osError.message}$additionalInfo');
    }
  }

  /// Disconnects TCP connection.
  @override
  void close() {
    socket.destroy();
    _connected = false;
  }

  @override
  int get hashCode =>
      address.hashCode ^ port.hashCode ^ socket.hashCode ^ _connected.hashCode;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TCPCommandSender &&
            runtimeType == other.runtimeType &&
            address == other.address &&
            port == other.port &&
            socket == other.socket &&
            isConnected == other.isConnected;
  }
}
