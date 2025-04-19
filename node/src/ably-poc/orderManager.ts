import { FdoIncomingOrder } from '@feedmepos/core/entity';

export class OrderManager {
  orders: FdoIncomingOrder[];
  constructor() {
    this.orders = [];
  }

  addOrder(order?: FdoIncomingOrder) {
    const result = FdoIncomingOrder.safeParse(order);
    if (!result.success) {
      console.error('Invalid order:', result.error.format());
      return;
    }
    order = FdoIncomingOrder.parse(order);
    order = order!;
    if (this.orders.length == 0) this.orders = [order];
    else {
      // find order by id and update if exist, or else append
      const index = this.orders.findIndex((o) => o._id === order._id);
      if (index === -1) this.orders.push(order);
      else this.orders[index] = order;
    }
    return order;
  }
}
