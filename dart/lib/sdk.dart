// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_scratchpad/ably_service.dart';

import 'package:feedme_core/feedme_core.dart';

// TODO: Declare the final entity in zod, convert to freezed, utilise here
class AblyMessage {
  final String action;
  final Map<String, dynamic> data;

  AblyMessage({
    required this.action,
    required this.data,
  });

  factory AblyMessage.fromJson(Map<String, dynamic> json) {
    return AblyMessage(
      action: json['action'],
      data: json['data'],
    );
  }

  @override
  String toString() {
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}

class OrderingSDK<T> {
  String restaurantId;
  final T Function(FdoIncomingOrder message) _transform;
  late AblyService ablyService;

  late Future<void> Function(T data) _onIncomingOrder;

  OrderingSDK(this.restaurantId, this._transform);

  Future<dynamic> _fetchToken() async {
    final httpClient = HttpClient();
    final url = Uri.parse('http://10.0.2.2:3000/token/$restaurantId');
    final request = await httpClient.getUrl(url);
    // request.headers
    //     .set('Authorization', 'Basic ${base64.encode(utf8.encode(apiKey))}');
    request.headers.set('Accept', 'application/json');
    request.headers.set('Content-Type', 'application/json');

    final response = await request.close();
    if (response.statusCode == 200) {
      final body = await response.transform(utf8.decoder).join();
      return body;
    } else {
      print('Failed to fetch ably token: ${response.statusCode}');
    }
  }

  Future<void> _fetchOrders() async {
    final client = HttpClient();
    final request = await client
        .getUrl(Uri.parse('http://10.0.2.2:3000/orders/$restaurantId'));
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch orders, $body');
    }
    final List<dynamic> decodedJson = jsonDecode(body);
    final List<FdoIncomingOrder> orders =
        decodedJson.map((e) => FdoIncomingOrder.fromJson(e)).toList();
    for (final order in orders) {
      _onIncomingOrder(order as T).then((_) async {
        await acknowledgeOrder(order);
      });
    }
    return;
  }

  Future<void> listen({
    required Future<void> Function(T data) onIncomingOrder,
    Future<void> Function(T data)? onUpdateDriver,
    Future<void> Function(String orderId)? onRefundOrder,
  }) async {
    _onIncomingOrder = onIncomingOrder;
    final token = await _fetchToken();
    ablyService = AblyService(token: token, channelName: restaurantId);
    await ablyService.connect();
    await _fetchOrders();

    ablyService.listen((data, name) async {
      if (name != 'order') return;
      final message = AblyMessage.fromJson(data);
      switch (message.action) {
        case 'new':
        case 'update':
          try {
            final order = FdoIncomingOrder.fromJson(message.data);
            if (order.status == F_INCOMING_ORDER_STATUS.PENDING) {
              _onIncomingOrder(_transform.call(order)).then((_) async {
                await acknowledgeOrder(order);
              });
            }
          } catch (err) {
            print(
                'Error parsing incoming order: $err\nMessage: ${message.toString()}');
          }
          break;
        default:
          print('Unknown action: $message');
          break;
      }
    }, onAction: (message) async {
      // print('[ABLY]: ACTION\n${message.toString()}');
    }, onDisconnect: () async {
      print('[ABLY]: Disconnected, reconnecting...');
      Timer.periodic(const Duration(seconds: 5), (timer) async {
        try {
          await listen(onIncomingOrder: onIncomingOrder);
          print('[ABLY]: Reconnected!');
          timer.cancel();
        } catch (e) {
          print('[ABLY]: Error reconnecting: $e, retrying in 5 seconds');
        }
      });
    });
  }

  Future<void> acknowledgeOrder(FdoIncomingOrder order) async {
    final client = HttpClient();
    final request = await client
        .postUrl(Uri.parse('http://10.0.2.2:3000/order/${order.id}/ack'));
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 201) {
      throw Exception('Failed to acknowledge order, $body');
    }
    return;
  }
}
