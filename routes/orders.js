const express = require('express');
const router = express.Router();
const db = require('../db');
const auth = require('../middleware/auth');

// Place order
router.post('/place', auth, async (req, res) => {
  const { shipping_address, payment_method } = req.body;
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    // Get cart items
    const [cart] = await conn.execute('SELECT cart_id FROM cart WHERE user_id = ?', [req.user.user_id]);
    if (!cart.length) return res.status(400).json({ error: 'Cart is empty' });

    const [items] = await conn.execute(
      `SELECT ci.product_id, ci.quantity, p.price, p.stock_quantity
       FROM cart_items ci JOIN products p ON ci.product_id = p.product_id
       WHERE ci.cart_id = ?`, [cart[0].cart_id]
    );

    // Check stock & calculate total
    let total = 0;
    for (const item of items) {
      if (item.quantity > item.stock_quantity)
        throw new Error(`Insufficient stock for product ${item.product_id}`);
      total += item.quantity * item.price;
    }

    // Create order
    const [order] = await conn.execute(
      'INSERT INTO orders (user_id, total_amount, shipping_address, payment_method) VALUES (?, ?, ?, ?)',
      [req.user.user_id, total, shipping_address, payment_method]
    );

    // Insert order items & update stock
    for (const item of items) {
      await conn.execute(
        'INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES (?, ?, ?, ?)',
        [order.insertId, item.product_id, item.quantity, item.price]
      );
      await conn.execute(
        'UPDATE products SET stock_quantity = stock_quantity - ? WHERE product_id = ?',
        [item.quantity, item.product_id]
      );
    }

    // Clear cart
    await conn.execute('DELETE FROM cart_items WHERE cart_id = ?', [cart[0].cart_id]);

    await conn.commit();
    res.json({ message: 'Order placed!', order_id: order.insertId, total });
  } catch (err) {
    await conn.rollback();
    res.status(500).json({ error: err.message });
  } finally {
    conn.release();
  }
});

// Get orders
router.get('/my-orders', auth, async (req, res) => {
  const [rows] = await db.execute(
    `SELECT o.order_id, o.total_amount, o.status, o.created_at,
     GROUP_CONCAT(p.name SEPARATOR ', ') AS products
     FROM orders o
     JOIN order_items oi ON o.order_id = oi.order_id
     JOIN products p ON oi.product_id = p.product_id
     WHERE o.user_id = ? GROUP BY o.order_id ORDER BY o.created_at DESC`,
    [req.user.user_id]
  );
  res.json(rows);
});

module.exports = router;