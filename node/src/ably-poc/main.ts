import { env } from './env';
import { OrderManager } from './orderManager';
import express, { Request, Response } from 'express';
import { Realtime } from 'ably';

export async function main() {
  // Create an express app
  const app = express();
  app.use(express.json());
  const ably = new Realtime(env.ABLY_API_KEY);

  const Orders = new OrderManager();

  (async () => {
    // new path to get ably token
    app.get('/token/:restaurantId', async (req: Request, res: Response) => {
      const token = req.params.restaurantId; // TODO: change to restaurant API token
      const restaurantId = req.params.restaurantId; // TODO: change to get from token
      const tokenRequest = await ably.auth.requestToken({
        ttl: 24 * 60 * 60 * 1000, // 24 hour
        clientId: restaurantId,
        capability: {
          [restaurantId]: ['subscribe', 'presence'],
        },
      });
      res.send(tokenRequest.token);
      return;
    });

    // new path to acknowledge order (acknowledged = status changed to PROCESSED)
    app.post('/order/:orderid/ack', async (req: Request, res: Response) => {
      const orderId = req.params.orderid;
      try {
        // find Order in DB
        const order = Orders.orders.find((o) => o._id === orderId);
        if (!order) {
          res.status(400).send({
            message: 'Invalid order',
          });
          return;
        }
        // mark Order as PROCESSED
        order.status = 'PROCESSED';
        res.status(201).send(order);
        return;
      } catch (e) {
        console.error(e);
        res.status(500).send(e);
        return;
      }
    });

    // Get all pending orders for a restaurant
    app.get('/orders/:restaurantId', (req: Request, res: Response) => {
      const restaurantId = req.params.restaurantId;
      console.log('restaurantId', restaurantId);
      res.send(Orders.orders.filter((o) => o.status == 'PENDING'));
      return;
    });

    // get specific order
    app.get('/order/:orderId', (req: Request, res: Response) => {
      const orderId = req.params.orderId;
      const order = Orders.orders.find((o) => o._id === orderId);
      if (order) res.send(order);
      else
        res.status(404).send({
          message: `Order with id ${orderId} not found`,
        });
      return;
    });

    // create new order to notify POS
    app.post('/:restaurantId/order', async (req: Request, res: Response) => {
      const message = req.body;
      const restaurantId = req.params.restaurantId;
      try {
        const order = Orders.addOrder({
          ...message,
          orderId: new Date().toISOString(),
          _id: new Date().toISOString(),
        });
        if (!order) {
          res.status(400).send({
            message: 'Invalid order',
          });
          return;
        }
        const channel = ably.channels.get(restaurantId);
        const presence = await channel.presence.get();
        if (presence.length == 0) {
          res.status(201).send(order);
          console.log('No one is listening to this channel:', restaurantId);
          return;
        }
        await channel.publish('order', {
          action: 'new',
          data: order,
        });
        // const messageId = await pubsub.publishMessage(restaurantId, order);
        console.log('Submitted order:', order._id);
        res.status(201).send(order);
        return;
      } catch (e) {
        console.error(e);
        res.status(500).send(e);
        return;
      }
    });

    // create new order to notify POS
    app.put(
      '/:restaurantId/order/:orderid',
      async (req: Request, res: Response) => {
        const restaurantId = req.params.restaurantId;
        const message = req.body;
        try {
          const order = Orders.addOrder(message);
          if (!order) {
            res.status(400).send({
              message: 'Invalid order',
            });
            return;
          }
          const channel = ably.channels.get(restaurantId);
          await channel.publish('order', order);

          // const messageId = await pubsub.publishMessage(restaurantId, order);
          console.log('Published message:', order._id);
          res.status(201).send(order);
          return;
        } catch (e) {
          console.error(e);
          res.status(500).send(e);
          return;
        }
      },
    );

    app.listen(3000, () => {
      console.log('Listening on port', 3000);
    });
  })();
}
