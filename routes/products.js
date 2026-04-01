const express = require('express');
const router = express.Router();
const db = require('../db');

// Get all products
router.get('/', async (req, res) => {
  const { category, search } = req.query;
  let query = `SELECT p.*, c.name AS category_name FROM products p 
               LEFT JOIN categories c ON p.category_id = c.category_id WHERE 1=1`;
  const params = [];

  if (category) { query += ' AND p.category_id = ?'; params.push(category); }
  if (search)   { query += ' AND p.name LIKE ?'; params.push(`%${search}%`); }

  const [rows] = await db.execute(query, params);
  res.json(rows);
});

// Get single product
router.get('/:id', async (req, res) => {
  const [rows] = await db.execute(
    `SELECT p.*, c.name AS category_name,
     ROUND(AVG(r.rating),1) AS avg_rating, COUNT(r.review_id) AS review_count
     FROM products p
     LEFT JOIN categories c ON p.category_id = c.category_id
     LEFT JOIN product_reviews r ON p.product_id = r.product_id
     WHERE p.product_id = ? GROUP BY p.product_id`,
    [req.params.id]
  );
  res.json(rows[0]);
});

module.exports = router;