-- ============================================================
-- NOVA MARKET - International E-Commerce Database
-- Physical model | 3NF | Rerunnable
-- ============================================================
DROP SCHEMA IF EXISTS nova_market;
CREATE SCHEMA nova_market
    DEFAULT CHARACTER SET utf8mb4       -- full Unicode: emoji, accents, international names
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE nova_market;

-- ============================================================
-- TABLE: categories
-- ============================================================
CREATE TABLE categories (
    category_id     INT             NOT NULL AUTO_INCREMENT,
    category_name   VARCHAR(100)    NOT NULL,               -- VARCHAR for indexing (TEXT can't be indexed directly)
    category_desc   LONGTEXT        NOT NULL,
    status          VARCHAR(20)     NOT NULL DEFAULT 'Active',

    PRIMARY KEY (category_id),
    UNIQUE KEY uq_category_name (category_name),            -- UNIQUE: no duplicate category names

    -- CHECK (3): status can only be a predefined value — like gender-style enum check
    CONSTRAINT chk_category_status CHECK (status IN ('Active', 'Inactive', 'Archived'))
) COMMENT = 'Product category definitions';

-- ============================================================
-- TABLE: suppliers
-- ============================================================
CREATE TABLE suppliers (
    supplier_id     INT             NOT NULL AUTO_INCREMENT,
    supplier_name   TEXT            NOT NULL,
    rating          DECIMAL(2,1)    NOT NULL DEFAULT 0.0,   -- DECIMAL avoids float rounding on displayed ratings
    date_joined     DATE            NOT NULL,
    phone_number    VARCHAR(15)     NOT NULL,

    PRIMARY KEY (supplier_id),

    -- CHECK (2): rating is a measured value — cannot be negative
    CONSTRAINT chk_supplier_rating_min  CHECK (rating >= 0.0),
    CONSTRAINT chk_supplier_rating_max  CHECK (rating <= 5.0),

    -- CHECK (1): date must be greater than January 1, 2026
    CONSTRAINT chk_supplier_date_joined CHECK (date_joined > '2026-01-01')
) COMMENT = 'Registered product suppliers';

-- ============================================================
-- TABLE: products
-- 3NF: category stored via FK — avoids transitive dep on category_name
-- ============================================================
CREATE TABLE products (
    product_id      INT             NOT NULL AUTO_INCREMENT,
    product_name    TEXT            NOT NULL,
    supplier_id     INT             NOT NULL,
    category_id     INT             NOT NULL,
    sale_count      INT             NOT NULL DEFAULT 0,
    price           DECIMAL(9,2)    NOT NULL,               -- DECIMAL(9,2): exact monetary precision
    product_rating  DECIMAL(2,1)    NOT NULL DEFAULT 0.0,
    stock           INT             NOT NULL DEFAULT 0,     -- INT: stock is always whole units

    PRIMARY KEY (product_id),
    CONSTRAINT fk_product_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),
    CONSTRAINT fk_product_category FOREIGN KEY (category_id) REFERENCES categories(category_id),

    -- CHECK (2): price & stock are measured values — cannot be negative
    CONSTRAINT chk_product_price        CHECK (price          >= 0.00),
    CONSTRAINT chk_product_stock        CHECK (stock          >= 0),
    CONSTRAINT chk_product_sale_count   CHECK (sale_count     >= 0),
    CONSTRAINT chk_product_rating_min   CHECK (product_rating >= 0.0),
    CONSTRAINT chk_product_rating_max   CHECK (product_rating <= 5.0)
) COMMENT = 'Product catalogue';

-- ============================================================
-- TABLE: pickup_points
-- ============================================================
CREATE TABLE pickup_points (
    point_id        INT             NOT NULL AUTO_INCREMENT,
    point_address   VARCHAR(255)    NOT NULL,
    point_number    VARCHAR(15)     NOT NULL,

    PRIMARY KEY (point_id)
) COMMENT = 'Physical order pickup locations';

-- ============================================================
-- TABLE: customers
-- ============================================================
CREATE TABLE customers (
    customer_id     INT             NOT NULL AUTO_INCREMENT,
    first_name      VARCHAR(255)    NOT NULL,
    last_name       VARCHAR(255)    NOT NULL,
    address         VARCHAR(255)    NOT NULL,
    date_of_birth   DATE            NOT NULL,
    date_joined     DATE            NOT NULL,
    phone_number    VARCHAR(15)     NOT NULL,
    gender          VARCHAR(20)     NOT NULL,               -- stored for demographics & personalisation

    PRIMARY KEY (customer_id),

    -- CHECK (1): date must be > 2026-01-01
    CONSTRAINT chk_customer_date_joined CHECK (date_joined   > '2026-01-01'),
    -- date_of_birth must precede join date (logical sanity)
    CONSTRAINT chk_customer_dob_order   CHECK (date_of_birth < date_joined),
    -- CHECK (3): gender can only be specific values — classic enum-style check
    CONSTRAINT chk_customer_gender      CHECK (gender IN ('Male', 'Female', 'Non-binary', 'Prefer not to say'))
) COMMENT = 'Registered customers';

-- ============================================================
-- TABLE: support_staff
-- ============================================================
CREATE TABLE support_staff (
    staff_id        INT             NOT NULL AUTO_INCREMENT,
    first_name      VARCHAR(255)    NOT NULL,
    last_name       VARCHAR(255)    NOT NULL,
    date_of_join    DATE            NOT NULL,
    position        VARCHAR(255)    NOT NULL,
    salary          DECIMAL(9,2)    NOT NULL,
    phone_number    VARCHAR(15)     NOT NULL,

    PRIMARY KEY (staff_id),

    -- CHECK (2): salary is a measured value — cannot be negative
    CONSTRAINT chk_staff_salary     CHECK (salary       >= 0.00),
    -- CHECK (1): hire date must be > 2026-01-01
    CONSTRAINT chk_staff_date_join  CHECK (date_of_join  > '2026-01-01')
) COMMENT = 'Customer support staff';

-- ============================================================
-- TABLE: payments
-- Created before orders; order_id FK added via ALTER after orders exists
-- ============================================================
CREATE TABLE payments (
    payment_id      INT             NOT NULL AUTO_INCREMENT,
    payment_type    SET('Card', 'Cash', 'Online', 'Crypto')  NOT NULL,
                                                            -- SET allows combination payment types
    bonus_added     DOUBLE          NOT NULL DEFAULT 0,     -- DOUBLE: loyalty points can be fractional
    payment_time    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (payment_id),

    -- CHECK (2): bonus is a measured value — cannot be negative
    CONSTRAINT chk_payment_bonus CHECK (bonus_added >= 0)
) COMMENT = 'Payment records';

-- ============================================================
-- TABLE: orders
-- ============================================================
CREATE TABLE orders (
    order_id        INT             NOT NULL AUTO_INCREMENT,
    order_date      DATE            NOT NULL,
    customer_id     INT             NOT NULL,
    supplier_id     INT             NOT NULL,
    product_id      INT             NOT NULL,
    payment_id      INT             NOT NULL,
    point_id        INT             NOT NULL,
    send_date       DATE            NOT NULL,
    est_arrival     DATE            NOT NULL,
    status          VARCHAR(30)     NOT NULL DEFAULT 'On the way',

    -- GENERATED: delivery window in days — derived, always stays in sync automatically
    delivery_days   INT GENERATED ALWAYS AS (DATEDIFF(est_arrival, send_date)) VIRTUAL,

    PRIMARY KEY (order_id),
    CONSTRAINT fk_order_customer  FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_order_supplier  FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),
    CONSTRAINT fk_order_product   FOREIGN KEY (product_id)  REFERENCES products(product_id),
    CONSTRAINT fk_order_payment   FOREIGN KEY (payment_id)  REFERENCES payments(payment_id),
    CONSTRAINT fk_order_point     FOREIGN KEY (point_id)    REFERENCES pickup_points(point_id),

    -- CHECK (1): order date must be > 2026-01-01
    CONSTRAINT chk_order_date   CHECK (order_date > '2026-01-01'),
    -- CHECK (3): status restricted to specific values
    CONSTRAINT chk_order_status CHECK (status IN ('On the way', 'Delivered', 'Cancelled', 'Returned'))
) COMMENT = 'Customer orders';

-- Resolve circular dependency: payments needs order_id FK but orders didn't exist yet
ALTER TABLE payments
    ADD COLUMN order_id INT NOT NULL AFTER payment_id,
    ADD CONSTRAINT fk_payment_order FOREIGN KEY (order_id) REFERENCES orders(order_id);

-- ============================================================
-- TABLE: product_reviews
-- Composite PK prevents duplicate reviews per customer+product pair
-- ============================================================
CREATE TABLE product_reviews (
    customer_id     INT             NOT NULL,
    product_id      INT             NOT NULL,
    review_text     MEDIUMTEXT      NOT NULL,               -- MEDIUMTEXT: up to 16MB for long reviews
    review_rating   DECIMAL(2,1)    NOT NULL,

    PRIMARY KEY (customer_id, product_id),                 -- composite PK = UNIQUE + NOT NULL enforced together
    CONSTRAINT fk_review_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_review_product  FOREIGN KEY (product_id)  REFERENCES products(product_id),

    -- CHECK (2): rating cannot be negative
    CONSTRAINT chk_review_rating_min CHECK (review_rating >= 0.0),
    CONSTRAINT chk_review_rating_max CHECK (review_rating <= 5.0)
) COMMENT = 'Customer product reviews';

-- ============================================================
-- TABLE: support_tickets
-- ============================================================
CREATE TABLE support_tickets (
    ticket_id       INT             NOT NULL AUTO_INCREMENT,
    order_id        INT             NOT NULL,
    payment_id      INT             NOT NULL,
    staff_id        INT             NOT NULL,
    status          VARCHAR(30)     NOT NULL DEFAULT 'Not resolved',

    PRIMARY KEY (ticket_id),
    CONSTRAINT fk_ticket_order   FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    CONSTRAINT fk_ticket_payment FOREIGN KEY (payment_id) REFERENCES payments(payment_id),
    CONSTRAINT fk_ticket_staff   FOREIGN KEY (staff_id)   REFERENCES support_staff(staff_id),

    -- CHECK (3): status restricted to specific values
    CONSTRAINT chk_ticket_status CHECK (status IN ('Not resolved', 'In progress', 'Resolved', 'Closed'))
) COMMENT = 'Customer support tickets';

-- ============================================================
-- 3NF SUMMARY:
--   1NF: atomic columns, no repeating groups, PKs defined
--   2NF: no partial deps (composite PK in product_reviews — all cols depend on full key)
--   3NF: no transitive deps — category_name not stored in products
-- FIVE CONSTRAINT TYPES COVERED:
--   (1) date > '2026-01-01'         → orders, suppliers, customers, staff
--   (2) non-negative measured value → price, stock, salary, rating, bonus
--   (3) specific value set (enum)   → gender, order status, ticket status, category status
--   (4) UNIQUE                      → uq_category_name
--   (5) NOT NULL                    → applied to every meaningful column
-- ============================================================
