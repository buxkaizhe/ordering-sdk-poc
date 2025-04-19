// ignore_for_file: avoid_print

import 'package:feedme_core/feedme_core.dart';
import 'package:flutter/material.dart';
import 'sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late OrderingSDK<FdoIncomingOrder> orderSDK;
  List<String> processingOrders = [];
  List<String> processedOrders = [];

  @override
  void initState() {
    super.initState();
    orderSDK = OrderingSDK('65b87a2833c130001b7b350a', (data) {
      return data;
    });

    // Start listening for messages in the background
    _startListening();
  }

  Future<void> onIncomingOrder(FdoIncomingOrder order) async {
    // This is where you handle the incoming order
    setState(() {
      processingOrders.add(order.id);
    });
    print("Processing order: ${order.id}");
    // simulate processing time randomly between 1 and 5 seconds
    await Future.delayed(
      Duration(
          seconds: (1 +
              (5 * (0.5 - (DateTime.now().millisecondsSinceEpoch % 100) / 100))
                  .round())),
    );
    print(
        'Order processed: ${order.id} | ${order.bill.items.values.map((item) => item.formattedName).join(",")}, ack order now');
    setState(() {
      processingOrders.remove(order.id);
      processedOrders.add(order.id);
    });
  }

  Future<void> _startListening() async {
    await orderSDK.listen(onIncomingOrder: (FdoIncomingOrder order) async {
      // This is where you handle the incoming order
      setState(() {
        processingOrders.add(order.id);
      });
      print("Processing order: ${order.id}");
      // simulate processing time randomly between 1 and 5 seconds
      await Future.delayed(
        Duration(
            seconds: (1 +
                (5 *
                        (0.5 -
                            (DateTime.now().millisecondsSinceEpoch % 100) /
                                100))
                    .round())),
      );
      print(
          'Order processed: ${order.id} | ${order.bill.items.values.map((item) => item.formattedName).join(",")}, ack order now');
      setState(() {
        processingOrders.remove(order.id);
        processedOrders.add(order.id);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Processing Orders:'),
                  ...processingOrders.map((orderId) => Text(orderId)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Processed Orders:'),
                  ...processedOrders.map((orderId) => Text(orderId)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
