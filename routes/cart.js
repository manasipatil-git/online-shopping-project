const express = require('express');
const router = express.Router();
const db = require('../db');
const auth = require('../middleware/auth');

// Get cart
router.get('/', auth, async (req, res) => {
  const [rows] = await db.execute(
    `SELECT ci.cart_item_id, p.product_id, p.name, p.price, p.image_url, ci.quantity,
     (ci.quantity * p.price) AS subtotal
     FROM cart ca
     JOIN cart_items ci ON ca.cart_id = ci.cart_id
     JOIN products p ON ci.product_id = p.product_id
     WHERE ca.user_id = ?`,
    [req.user.user_id]
  );
  const total = rows.reduce((sum, item) => sum + Number(item.subtotal), 0);
  res.json({ items: rows, total });
});

// Add to cart
router.post('/add', auth, async (req, res) => {
  const { product_id, quantity = 1 } = req.body;
  const conn = await db.getConnection();
  try {
    let [cart] = await conn.execute('SELECT cart_id FROM cart WHERE user_id = ?', [req.user.user_id]);
    let cart_id;
    if (!cart.length) {
      const [result] = await conn.execute('INSERT INTO cart (user_id) VALUES (?)', [req.user.user_id]);
      cart_id = result.insertId;
    } else {
      cart_id = cart[0].cart_id;
    }

    const [existing] = await conn.execute(
      'SELECT * FROM cart_items WHERE cart_id = ? AND product_id = ?', [cart_id, product_id]
    );
    if (existing.length) {
      await conn.execute(
        'UPDATE cart_items SET quantity = quantity + ? WHERE cart_id = ? AND product_id = ?',
        [quantity, cart_id, product_id]
      );
    } else {
      await conn.execute(
        'INSERT INTO cart_items (cart_id, product_id, quantity) VALUES (?, ?, ?)',
        [cart_id, product_id, quantity]
      );
    }
    res.json({ message: 'Added to cart' });
  } finally {
    conn.release();
  }
});

// Remove from cart
router.delete('/remove/:item_id', auth, async (req, res) => {
  await db.execute('DELETE FROM cart_items WHERE cart_item_id = ?', [req.params.item_id]);
  res.json({ message: 'Removed from cart' });
});

module.exports = router;