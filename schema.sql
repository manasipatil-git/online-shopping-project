CREATE DATABASE online_shop;
USE online_shop;

-- 1. Categories
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Users
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    phone VARCHAR(15),
    address TEXT,
    role ENUM('customer', 'admin') DEFAULT 'customer',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Products
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INT DEFAULT 0,
    image_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE SET NULL
);

-- 4. Cart
CREATE TABLE cart (
    cart_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 5. Cart Items
CREATE TABLE cart_items (
    cart_item_id INT AUTO_INCREMENT PRIMARY KEY,
    cart_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT DEFAULT 1,
    FOREIGN KEY (cart_id) REFERENCES cart(cart_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

-- 6. Orders
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    status ENUM('pending', 'confirmed', 'shipped', 'delivered', 'cancelled') DEFAULT 'pending',
    shipping_address TEXT,
    payment_method VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 7. Order Items
CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- 8. Product Reviews
CREATE TABLE product_reviews (
    review_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    user_id INT NOT NULL,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 9. Payments
CREATE TABLE payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    payment_status ENUM('pending', 'completed', 'failed', 'refunded') DEFAULT 'pending',
    transaction_id VARCHAR(100),
    paid_at TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

INSERT INTO categories (name, description) VALUES
('Electronics', 'Phones, laptops, gadgets'),
('Clothing', 'Shirts, pants, shoes'),
('Books', 'Fiction, non-fiction, textbooks'),
('Home & Kitchen', 'Appliances and decor');

INSERT INTO users (name, email, password_hash, phone, role) VALUES
('Alice Singh', 'alice@example.com', 'hashed_pw_1', '9876543210', 'customer'),
('Bob Patel', 'bob@example.com', 'hashed_pw_2', '9123456789', 'customer'),
('Admin User', 'admin@shop.com', 'hashed_pw_admin', '9000000000', 'admin');

INSERT INTO products (category_id, name, description, price, stock_quantity, image_url) VALUES
(1, 'Wireless Earbuds', 'Noise cancelling earbuds', 1999.00, 50, '/images/earbuds.jpg'),
(1, 'Smartphone X', '128GB, 5G capable', 29999.00, 30, '/images/phone.jpg'),
(2, 'Cotton T-Shirt', 'Comfortable daily wear', 499.00, 200, '/images/tshirt.jpg'),
(3, 'DBMS Textbook', 'Silberschatz 7th Edition', 799.00, 40, '/images/book.jpg'),
(4, 'Electric Kettle', '1.5L fast boil', 1299.00, 60, '/images/kettle.jpg');

-- 1. View all products with category name
SELECT p.product_id, p.name, p.price, p.stock_quantity, c.name AS category
FROM products p
JOIN categories c ON p.category_id = c.category_id;

-- 2. Get user's cart with total
SELECT u.name, p.name AS product, ci.quantity,
       (ci.quantity * p.price) AS subtotal
FROM users u
JOIN cart ca ON u.user_id = ca.user_id
JOIN cart_items ci ON ca.cart_id = ci.cart_id
JOIN products p ON ci.product_id = p.product_id
WHERE u.user_id = 1;

-- 3. Place an order (Transaction)
START TRANSACTION;
  INSERT INTO orders (user_id, total_amount, shipping_address, payment_method)
  VALUES (1, 31998.00, '123 MG Road, Mumbai', 'UPI');
  
  SET @order_id = LAST_INSERT_ID();
  
  INSERT INTO order_items (order_id, product_id, quantity, unit_price)
  VALUES (@order_id, 1, 1, 1999.00),
         (@order_id, 2, 1, 29999.00);
  
  -- Reduce stock
  UPDATE products SET stock_quantity = stock_quantity - 1 WHERE product_id IN (1, 2);
COMMIT;

-- 4. Get order history for a user
SELECT o.order_id, o.total_amount, o.status, o.created_at,
       GROUP_CONCAT(p.name SEPARATOR ', ') AS items
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.user_id = 1
GROUP BY o.order_id;

-- 5. Top selling products
SELECT p.name, SUM(oi.quantity) AS total_sold
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_id
ORDER BY total_sold DESC
LIMIT 5;

-- 6. Average rating per product
SELECT p.name, ROUND(AVG(r.rating), 1) AS avg_rating, COUNT(*) AS reviews
FROM product_reviews r
JOIN products p ON r.product_id = p.product_id
GROUP BY p.product_id;

-- 7. Revenue by category
SELECT c.name AS category, SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.status != 'cancelled'
GROUP BY c.category_id
ORDER BY revenue DESC;

