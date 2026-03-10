-- ============================================
--  Online Shopping Platform - MySQL Schema
-- ============================================

CREATE DATABASE IF NOT EXISTS online_shop;
USE online_shop;

-- ----------------------------
-- Categories
-- ----------------------------
CREATE TABLE Categories (
    CategoryID   INT          NOT NULL AUTO_INCREMENT,
    CategoryName VARCHAR(15)  NOT NULL,
    CategoryDesc LONGTEXT     NOT NULL,
    Status       ENUM('Active', 'Inactive') NOT NULL DEFAULT 'Active',
    PRIMARY KEY (CategoryID)
);

-- ----------------------------
-- Suppliers
-- ----------------------------
CREATE TABLE Suppliers (
    SuppliersID         INT          NOT NULL AUTO_INCREMENT,
    SuppliersName       TEXT         NOT NULL,
    SuppliersRating     DECIMAL(2,1) CHECK (SuppliersRating BETWEEN 0 AND 5),
    SuppliersDateJoined DATE         NOT NULL,
    FullNumber          VARCHAR(15)  NOT NULL,
    PRIMARY KEY (SuppliersID)
);

-- ----------------------------
-- Customer
-- ----------------------------
CREATE TABLE Customer (
    CustomerID      INT          NOT NULL AUTO_INCREMENT,
    CustomerName    VARCHAR(255) NOT NULL,
    CustomerLastName TEXT        NOT NULL,
    CustomerAddress  TEXT        NOT NULL,
    CustomerDOB     DATE         NOT NULL,
    CustomerJoin    DATE         NOT NULL DEFAULT (CURRENT_DATE),
    FullNumber      VARCHAR(15)  NOT NULL,
    PRIMARY KEY (CustomerID),
    UNIQUE (FullNumber)
);

-- ----------------------------
-- Product
-- ----------------------------
CREATE TABLE Product (
    ProductID       INT            NOT NULL AUTO_INCREMENT,
    ProductName     TEXT           NOT NULL,
    SuppliersID     INT            NOT NULL,
    ProductCategory INT            NOT NULL,
    SaleCount       INT            NOT NULL DEFAULT 0,
    Price           DECIMAL(9,2)   NOT NULL CHECK (Price >= 0),
    ProductRating   DECIMAL(2,1)   CHECK (ProductRating BETWEEN 0 AND 5),
    Stock           INT            NOT NULL DEFAULT 0 CHECK (Stock >= 0),
    PRIMARY KEY (ProductID),
    CONSTRAINT fk_product_supplier  FOREIGN KEY (SuppliersID)     REFERENCES Suppliers(SuppliersID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_product_category  FOREIGN KEY (ProductCategory) REFERENCES Categories(CategoryID) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ----------------------------
-- Payment
-- ----------------------------
CREATE TABLE Payment (
    PaymentID   INT       NOT NULL AUTO_INCREMENT,
    PaymentType ENUM('Credit Card', 'Debit Card', 'Cash on Delivery', 'E-Wallet', 'Bank Transfer') NOT NULL,
    BonusAdded  DECIMAL(9,2) NOT NULL DEFAULT 0.00,
    PaymentTime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (PaymentID)
);

-- ----------------------------
-- Order Pickup Point
-- ----------------------------
CREATE TABLE OrderPickupPoint (
    PointID      INT          NOT NULL AUTO_INCREMENT,
    PointAddress VARCHAR(255) NOT NULL,
    PointNumber  VARCHAR(15)  NOT NULL,
    PRIMARY KEY (PointID)
);

-- ----------------------------
-- Order Information
-- ----------------------------
CREATE TABLE OrderInformation (
    OrderID     INT  NOT NULL AUTO_INCREMENT,
    OrderDate   DATE NOT NULL DEFAULT (CURRENT_DATE),
    CustomerID  INT  NOT NULL,
    ProductID   INT  NOT NULL,
    PaymentID   INT  NOT NULL,
    PointID     INT  NOT NULL,
    SendDate    DATE NOT NULL,
    EstArrival  DATE NOT NULL,
    Status      ENUM('On the way', 'Delivered', 'Cancelled', 'Processing', 'Returned') NOT NULL DEFAULT 'Processing',
    PRIMARY KEY (OrderID),
    CONSTRAINT fk_order_customer FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_order_product  FOREIGN KEY (ProductID)  REFERENCES Product(ProductID)   ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_order_payment  FOREIGN KEY (PaymentID)  REFERENCES Payment(PaymentID)   ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_order_point    FOREIGN KEY (PointID)    REFERENCES OrderPickupPoint(PointID) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_dates         CHECK (EstArrival >= SendDate)
);

-- ----------------------------
-- Product Reviews
-- ----------------------------
CREATE TABLE ProductReviews (
    ReviewID     INT         NOT NULL AUTO_INCREMENT,
    CustomerID   INT         NOT NULL,
    ProductID    INT         NOT NULL,
    ReviewText   MEDIUMTEXT,
    ReviewRating DECIMAL(2,1) NOT NULL CHECK (ReviewRating BETWEEN 0 AND 5),
    CreatedAt    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ReviewID),
    CONSTRAINT fk_review_customer FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_review_product  FOREIGN KEY (ProductID)  REFERENCES Product(ProductID)   ON UPDATE CASCADE ON DELETE CASCADE,
    UNIQUE (CustomerID, ProductID)   -- one review per customer per product
);

-- ----------------------------
-- Support Ticket
-- ----------------------------
CREATE TABLE SupportTicket (
    TicketID  INT NOT NULL AUTO_INCREMENT,
    OrderID   INT NOT NULL,
    PaymentID INT NOT NULL,
    Status    ENUM('Not resolved', 'In progress', 'Resolved', 'Closed') NOT NULL DEFAULT 'Not resolved',
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (TicketID),
    CONSTRAINT fk_ticket_order   FOREIGN KEY (OrderID)   REFERENCES OrderInformation(OrderID)   ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_ticket_payment FOREIGN KEY (PaymentID) REFERENCES Payment(PaymentID) ON UPDATE CASCADE ON DELETE RESTRICT
);
