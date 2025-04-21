// ignore_for_file: avoid_print, constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';

// ignore: camel_case_types
enum ABLY_ACTION {
  HEARTBEAT,
  ACK,
  NACK,
  CONNECT,
  CONNECTED,
  DISCONNECT,
  DISCONNECTED,
  CLOSE,
  CLOSED,
  ERROR,
  ATTACH,
  ATTACHED,
  DETACH,
  DETACHED,
  PRESENCE,
  MESSAGE,
  SYNC,
  AUTH,
  ACTIVATE,
  STATE,
  STATE_SYNC,
  ANNOTATION
}

// ignore: camel_case_types
enum ABLY_PRESENCE_ACTION {
  UNKNOWN,
  PRESENT,
  ENTER,
  LEAVE,
  UPDATE,
}

class AblyService {
  final HttpClient httpClient = HttpClient();
  final dynamic token;
  final String channelName;
  final encoder = const JsonEncoder.withIndent('  ');

  late final WebSocketChannel ws;

  AblyService({
    required this.token,
    required this.channelName,
  });

  Future<void> connect() async {
    final uri = Uri(
      scheme: 'wss',
      host: 'realtime.ably.io',
      port: 443,
      queryParameters: {
        'accessToken': token,
        'echo': 'true',
      },
    );

    ws = WebSocketChannel.connect(uri);
    await ws.ready;
  }

  void _connectChannel() {
    final attachMsg = {
      'action': ABLY_ACTION.ATTACH.index,
      'channel': channelName,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    ws.sink.add(jsonEncode(attachMsg));
  }

  void _enterPresence() {
    final msg = {
      'action': ABLY_ACTION.PRESENCE.index,
      'channel': channelName,
      'msgSerial': DateTime.now().millisecondsSinceEpoch.toString(),
      'presence': [
        {
          'action': ABLY_PRESENCE_ACTION.ENTER.index,
          'clientId': channelName,
          'data': {'status': 'online'}
        }
      ]
    };
    ws.sink.add(jsonEncode(msg));
  }

  void listen(
    Future<void> Function(
      Map<String, dynamic> data,
      String? name,
    ) onMessage, {
    Future<void> Function(Map<String, dynamic>)? onAction,
    Future<void> Function(dynamic)? onParsingError,
    required Future<void> Function() onDisconnect,
  }) {
    ws.stream.timeout(const Duration(seconds: 20), onTimeout: (_) async {
      await onDisconnect.call();
      _.close();
      ws.sink.close();
    }).listen((data) {
      try {
        final json = jsonDecode(data);
        ABLY_ACTION action = ABLY_ACTION.values[json['action']];
        final prettyMessage = encoder.convert(json);
        // print('[ABLY]: ${action.name}\n$prettyMessage');
        switch (action) {
          case ABLY_ACTION.HEARTBEAT:
            print('[ABLY]: ${action.name}\n$prettyMessage');
            break;
          case ABLY_ACTION.ATTACHED: // ATTACHED
            print('[ABLY]: ${action.name}\n$prettyMessage');
            _enterPresence();
            break;
          case ABLY_ACTION.MESSAGE: // MESSAGE
            print('[ABLY]: MESSAGE\n$prettyMessage');
            if (json['messages'] != null) {
              for (var message in json['messages']) {
                onMessage(
                  jsonDecode((message['data'])),
                  message['name'],
                );
              }
            }
            break;
          default:
            break;
        }
        onAction?.call(json);
      } catch (e) {
        onParsingError?.call(e);
      }
    }, onError: (error) async {
      print('[ABLY]: WebSocket error: $error');
      await onDisconnect.call();
      ws.sink.close();
    }, onDone: () async {
      print('[ABLY]: WebSocket done');
      await onDisconnect.call();
      ws.sink.close();
    });
    _connectChannel();
  }

  void disconnect() {
    ws.sink.close();
  }
}
