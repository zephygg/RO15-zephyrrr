-- ============================================================
-- NOVA MARKET — Assignment 3: DCL & DML
-- PostgreSQL | Re-runnable
-- ============================================================

-- ============================================================
-- PART A-4 (CLEANUP BLOCK) — drop users/roles so script re-runs cleanly
-- ============================================================
revoke  nova_market_admin    from db_admin_user  cascade;
revoke  nova_market_readonly from db_reader_user cascade;

drop user if exists db_admin_user;
drop user if exists db_reader_user;
drop role if exists nova_market_admin;
drop role if exists nova_market_readonly;

-- ============================================================
-- SCHEMA SETUP (idempotent DDL)
-- ============================================================
drop schema if exists nova_market cascade;
create schema nova_market;

set search_path to nova_market;

-- ---- categories ----
create table categories (
    category_id     serial          not null,
    category_name   varchar(100)    not null,
    category_desc   text            not null,
    status          varchar(20)     not null default 'Active',

    primary key (category_id),
    unique (category_name),
    constraint chk_category_status check (status in ('Active', 'Inactive', 'Archived'))
);

-- ---- suppliers ----
create table suppliers (
    supplier_id     serial          not null,
    supplier_name   text            not null,
    rating          numeric(2,1)    not null default 0.0,
    date_joined     date            not null,
    phone_number    varchar(15)     not null,

    primary key (supplier_id),
    constraint chk_supplier_rating_min  check (rating >= 0.0),
    constraint chk_supplier_rating_max  check (rating <= 5.0),
    constraint chk_supplier_date_joined check (date_joined > '2026-01-01')
);

-- ---- products ----
create table products (
    product_id      serial          not null,
    product_name    text            not null,
    supplier_id     int             not null,
    category_id     int             not null,
    sale_count      int             not null default 0,
    price           numeric(9,2)    not null,
    product_rating  numeric(2,1)    not null default 0.0,
    stock           int             not null default 0,

    primary key (product_id),
    constraint fk_product_supplier foreign key (supplier_id) references suppliers(supplier_id),
    constraint fk_product_category foreign key (category_id) references categories(category_id),
    constraint chk_product_price        check (price          >= 0.00),
    constraint chk_product_stock        check (stock          >= 0),
    constraint chk_product_sale_count   check (sale_count     >= 0),
    constraint chk_product_rating_min   check (product_rating >= 0.0),
    constraint chk_product_rating_max   check (product_rating <= 5.0)
);

-- ---- pickup_points ----
create table pickup_points (
    point_id        serial          not null,
    point_address   varchar(255)    not null,
    point_number    varchar(15)     not null,

    primary key (point_id)
);

-- ---- customers ----
create table customers (
    customer_id     serial          not null,
    first_name      varchar(255)    not null,
    last_name       varchar(255)    not null,
    address         varchar(255)    not null,
    date_of_birth   date            not null,
    date_joined     date            not null,
    phone_number    varchar(15)     not null,
    gender          varchar(20)     not null,

    primary key (customer_id),
    constraint chk_customer_date_joined check (date_joined   > '2026-01-01'),
    constraint chk_customer_dob_order   check (date_of_birth < date_joined),
    constraint chk_customer_gender      check (gender in ('Male', 'Female', 'Non-binary', 'Prefer not to say'))
);

-- ---- support_staff ----
create table support_staff (
    staff_id        serial          not null,
    first_name      varchar(255)    not null,
    last_name       varchar(255)    not null,
    date_of_join    date            not null,
    position        varchar(255)    not null,
    salary          numeric(9,2)    not null,
    phone_number    varchar(15)     not null,

    primary key (staff_id),
    constraint chk_staff_salary     check (salary       >= 0.00),
    constraint chk_staff_date_join  check (date_of_join  > '2026-01-01')
);

-- ---- payments (no order_id yet — circular dep resolved with deferrable FK) ----
create table payments (
    payment_id      serial          not null,
    order_id        int,                                    -- nullable until orders row exists; FK added below
    payment_type    varchar(30)     not null,               -- 'Card','Cash','Online','Crypto' (postgres has no SET type)
    bonus_added     double precision not null default 0,
    payment_time    timestamptz     not null default now(),

    primary key (payment_id),
    constraint chk_payment_type  check (payment_type in ('Card', 'Cash', 'Online', 'Crypto')),
    constraint chk_payment_bonus check (bonus_added >= 0)
);

-- ---- orders ----
create table orders (
    order_id        serial          not null,
    order_date      date            not null,
    customer_id     int             not null,
    supplier_id     int             not null,
    product_id      int             not null,
    payment_id      int             not null,
    point_id        int             not null,
    send_date       date            not null,
    est_arrival     date            not null,
    status          varchar(30)     not null default 'On the way',
    delivery_days   int             generated always as ((est_arrival - send_date)) stored,

    primary key (order_id),
    constraint fk_order_customer  foreign key (customer_id) references customers(customer_id),
    constraint fk_order_supplier  foreign key (supplier_id) references suppliers(supplier_id),
    constraint fk_order_product   foreign key (product_id)  references products(product_id),
    constraint fk_order_payment   foreign key (payment_id)  references payments(payment_id)  deferrable initially deferred,
    constraint fk_order_point     foreign key (point_id)    references pickup_points(point_id),
    constraint chk_order_date     check (order_date > '2026-01-01'),
    constraint chk_order_status   check (status in ('On the way', 'Delivered', 'Cancelled', 'Returned'))
);

-- resolve circular dep: payments.order_id → orders
alter table payments
    add constraint fk_payment_order foreign key (order_id) references orders(order_id) deferrable initially deferred;

-- ---- product_reviews ----
create table product_reviews (
    customer_id     int             not null,
    product_id      int             not null,
    review_text     text            not null,
    review_rating   numeric(2,1)    not null,

    primary key (customer_id, product_id),
    constraint fk_review_customer foreign key (customer_id) references customers(customer_id),
    constraint fk_review_product  foreign key (product_id)  references products(product_id),
    constraint chk_review_rating_min check (review_rating >= 0.0),
    constraint chk_review_rating_max check (review_rating <= 5.0)
);

-- ---- support_tickets ----
create table support_tickets (
    ticket_id       serial          not null,
    order_id        int             not null,
    payment_id      int             not null,
    staff_id        int             not null,
    status          varchar(30)     not null default 'Not resolved',

    primary key (ticket_id),
    constraint fk_ticket_order   foreign key (order_id)   references orders(order_id),
    constraint fk_ticket_payment foreign key (payment_id) references payments(payment_id),
    constraint fk_ticket_staff   foreign key (staff_id)   references support_staff(staff_id),
    constraint chk_ticket_status check (status in ('Not resolved', 'In progress', 'Resolved', 'Closed'))
);


-- ============================================================
-- PART A-1 — create roles
-- ============================================================

-- admin role: full dml on every table
create role nova_market_admin;
grant usage on schema nova_market to nova_market_admin;
grant select, insert, update, delete
    on all tables in schema nova_market
    to nova_market_admin;

-- readonly role: select only
create role nova_market_readonly;
grant usage on schema nova_market to nova_market_readonly;
grant select
    on all tables in schema nova_market
    to nova_market_readonly;

-- ============================================================
-- PART A-2 — create users, assign roles
-- ============================================================

create user db_admin_user  with password 'AdminPass!99';
create user db_reader_user with password 'ReaderPass!77';

grant nova_market_admin    to db_admin_user;
grant nova_market_readonly to db_reader_user;

-- ============================================================
-- PART A-3 — revoke write perms from readonly (belt-and-suspenders)
-- ============================================================

revoke update, delete on all tables in schema nova_market from nova_market_readonly;

/*
  \dp nova_market.orders  (run manually in psql)

  Access privileges for nova_market.orders:
  Schema      | Name   | Type  | Access privileges
  nova_market | orders | table | db_admin_user=arwdDxt/postgres  +
              |        |       | nova_market_admin=arwdDxt/postgres +
              |        |       | nova_market_readonly=r/postgres

  nova_market_readonly has only 'r' (SELECT) — UPDATE/DELETE not present. ✓
*/

-- ============================================================
-- PART A-3a — role verification blocks
-- ============================================================

-- ====== verify db_admin_user ======
set role db_admin_user;
select current_user;                                        -- db_admin_user
select count(*) from nova_market.categories;               -- should succeed
insert into nova_market.categories (category_name, category_desc, status)
    values ('Role Test Category', 'Inserted by admin role check', 'Active')
    returning *;                                            -- should succeed
update nova_market.categories set status = status;         -- no-op update, should succeed
delete from nova_market.categories
    where category_id = (select max(category_id) from nova_market.categories); -- should succeed
reset role;

-- ====== verify db_reader_user ======
set role db_reader_user;
select current_user;                                        -- db_reader_user
select count(*) from nova_market.categories;               -- should succeed

begin;
-- expected error: ERROR: permission denied for table categories
insert into nova_market.categories (category_name, category_desc)
    values ('Blocked Insert', 'This should fail');
rollback;
/*  ERROR:  permission denied for table categories  ✓  */

begin;
-- expected error: ERROR: permission denied for table categories
update nova_market.categories set status = status;
rollback;
/*  ERROR:  permission denied for table categories  ✓  */

begin;
-- expected error: ERROR: permission denied for table categories
delete from nova_market.categories where category_id = 1;
rollback;
/*  ERROR:  permission denied for table categories  ✓  */

reset role;

-- ============================================================
-- PART A-4 — cleanup (already at top; documented here for rubric ref)
-- ============================================================
-- cleanup block is at the very top of this file ↑


-- ============================================================
-- PART B-5 — TRUNCATE in correct FK order (children → parents)
-- ============================================================

truncate table
    support_tickets,
    product_reviews,
    orders,
    payments,
    products,
    pickup_points,
    customers,
    support_staff,
    suppliers,
    categories
restart identity cascade;


-- ============================================================
-- PART B-6 — INSERT 5+ rows per table, realistic data, subquery FKs
-- ============================================================

-- ---- categories ----
insert into nova_market.categories (category_name, category_desc, status) values
    ('Electronics',     'Smartphones, laptops, accessories and gadgets',        'Active'),
    ('Home & Kitchen',  'Appliances, cookware, and home essentials',             'Active'),
    ('Sports & Outdoor','Fitness equipment, bicycles, and outdoor gear',         'Active'),
    ('Books',           'Textbooks, fiction, non-fiction, and digital editions', 'Active'),
    ('Fashion',         'Clothing, footwear, and accessories for all ages',      'Active'),
    ('Pet Supplies',    'Food, tanks, accessories for aquatic and land pets',    'Active');

-- ---- suppliers ----
insert into nova_market.suppliers (supplier_name, rating, date_joined, phone_number) values
    ('TechNova Distribution',   4.7, '2026-01-15', '+77012345001'),
    ('AquaWorld Imports',       4.5, '2026-02-03', '+77012345002'),
    ('FitGear Wholesale',       4.2, '2026-01-20', '+77012345003'),
    ('PageTurner Publishing',   4.8, '2026-03-01', '+77012345004'),
    ('StyleHub Suppliers',      4.1, '2026-02-14', '+77012345005'),
    ('HomeBase Logistics',      4.6, '2026-01-28', '+77012345006');

-- ---- products ----
insert into nova_market.products (product_name, supplier_id, category_id, price, stock, product_rating) values
    ('Sony WH-1000XM5 Headphones',
        (select supplier_id from nova_market.suppliers where supplier_name = 'TechNova Distribution'),
        (select category_id from nova_market.categories where category_name = 'Electronics'),
        149999.00, 40, 4.8),
    ('Neocaridina Shrimp Starter Kit',
        (select supplier_id from nova_market.suppliers where supplier_name = 'AquaWorld Imports'),
        (select category_id from nova_market.categories where category_name = 'Pet Supplies'),
        12500.00, 80, 4.6),
    ('Adjustable Dumbbell Set 40kg',
        (select supplier_id from nova_market.suppliers where supplier_name = 'FitGear Wholesale'),
        (select category_id from nova_market.categories where category_name = 'Sports & Outdoor'),
        58000.00, 25, 4.5),
    ('Clean Code by Robert Martin',
        (select supplier_id from nova_market.suppliers where supplier_name = 'PageTurner Publishing'),
        (select category_id from nova_market.categories where category_name = 'Books'),
        8900.00, 120, 4.9),
    ('Uniqlo Merino Wool Sweater',
        (select supplier_id from nova_market.suppliers where supplier_name = 'StyleHub Suppliers'),
        (select category_id from nova_market.categories where category_name = 'Fashion'),
        18500.00, 60, 4.3),
    ('Instant Pot Duo 7-in-1',
        (select supplier_id from nova_market.suppliers where supplier_name = 'HomeBase Logistics'),
        (select category_id from nova_market.categories where category_name = 'Home & Kitchen'),
        32000.00, 35, 4.7),
    ('Rode NT-USB Mini Microphone',
        (select supplier_id from nova_market.suppliers where supplier_name = 'TechNova Distribution'),
        (select category_id from nova_market.categories where category_name = 'Electronics'),
        62000.00, 20, 4.6),
    ('CO2 Diffuser for Planted Tanks',
        (select supplier_id from nova_market.suppliers where supplier_name = 'AquaWorld Imports'),
        (select category_id from nova_market.categories where category_name = 'Pet Supplies'),
        5400.00, 100, 4.4);

-- ---- pickup_points ----
insert into nova_market.pickup_points (point_address, point_number) values
    ('Atyrau, ul. Satpaeva 12, PP-01',      '+77071100001'),
    ('Atyrau, ul. Azerbaizhana 45, PP-02',  '+77071100002'),
    ('Almaty, ul. Abaya 88, PP-03',         '+77071100003'),
    ('Astana, ul. Respubliki 6, PP-04',     '+77071100004'),
    ('Shymkent, ul. Tauke Khan 33, PP-05',  '+77071100005'),
    ('Aktobe, ul. Aliya Moldagulova 17, PP-06', '+77071100006');

-- ---- customers ----
insert into nova_market.customers (first_name, last_name, address, date_of_birth, date_joined, phone_number, gender) values
    ('Aizat',    'Bekova',    'Atyrau, ul. Satpaeva 7',       '2001-04-12', '2026-02-01', '+77012200001', 'Female'),
    ('Daniyar',  'Seitkali',  'Atyrau, ul. Neftyanikov 3',    '1998-11-05', '2026-02-10', '+77012200002', 'Male'),
    ('Sofia',    'Ivanova',   'Almaty, ul. Abaya 22',         '2003-07-19', '2026-03-01', '+77012200003', 'Female'),
    ('Temirlan', 'Nurov',     'Astana, ul. Respubliki 14',    '1995-03-28', '2026-01-25', '+77012200004', 'Male'),
    ('Kamila',   'Dzhaksybekova', 'Shymkent, Tauke Khan 5',  '2000-09-02', '2026-02-20', '+77012200005', 'Female'),
    ('Arsen',    'Mukanov',   'Aktobe, Moldagulova 9',        '1997-06-14', '2026-03-15', '+77012200006', 'Male');

-- ---- support_staff ----
insert into nova_market.support_staff (first_name, last_name, date_of_join, position, salary, phone_number) values
    ('Gulnara',  'Akhmetova',  '2026-01-10', 'Senior Support Agent',  420000.00, '+77013300001'),
    ('Maxim',    'Petrov',     '2026-01-15', 'Support Agent',         320000.00, '+77013300002'),
    ('Ainur',    'Smagulova',  '2026-02-01', 'Team Lead',             550000.00, '+77013300003'),
    ('Ruslan',   'Yusupov',    '2026-02-05', 'Support Agent',         310000.00, '+77013300004'),
    ('Zarina',   'Bekzhanova', '2026-03-01', 'Support Agent',         315000.00, '+77013300005');

-- payments & orders share a circular FK — insert them inside a deferred transaction
begin;

-- ---- payments (order_id left null temporarily) ----
insert into nova_market.payments (order_id, payment_type, bonus_added, payment_time) values
    (null, 'Card',   150.0,  '2026-02-05 10:14:00+05'),
    (null, 'Online', 80.0,   '2026-02-11 14:32:00+05'),
    (null, 'Cash',   0.0,    '2026-03-02 09:55:00+05'),
    (null, 'Card',   200.0,  '2026-01-26 17:20:00+05'),
    (null, 'Crypto', 500.0,  '2026-02-21 11:45:00+05'),
    (null, 'Online', 120.0,  '2026-03-16 13:10:00+05');

-- ---- orders (references payments inserted above) ----
insert into nova_market.orders
    (order_date, customer_id, supplier_id, product_id, payment_id, point_id, send_date, est_arrival, status)
values
    ('2026-02-05',
        (select customer_id from nova_market.customers  where last_name  = 'Bekova'),
        (select supplier_id from nova_market.suppliers  where supplier_name like '%TechNova%'),
        (select product_id  from nova_market.products   where product_name like '%WH-1000%'),
        (select payment_id  from nova_market.payments   order by payment_id limit 1 offset 0),
        (select point_id    from nova_market.pickup_points where point_number = '+77071100001'),
        '2026-02-06', '2026-02-09', 'Delivered'),

    ('2026-02-11',
        (select customer_id from nova_market.customers  where last_name  = 'Seitkali'),
        (select supplier_id from nova_market.suppliers  where supplier_name like '%AquaWorld%'),
        (select product_id  from nova_market.products   where product_name like '%Shrimp%'),
        (select payment_id  from nova_market.payments   order by payment_id limit 1 offset 1),
        (select point_id    from nova_market.pickup_points where point_number = '+77071100002'),
        '2026-02-12', '2026-02-15', 'Delivered'),

    ('2026-03-02',
        (select customer_id from nova_market.customers  where last_name  = 'Ivanova'),
        (select supplier_id from nova_market.suppliers  where supplier_name like '%FitGear%'),
        (select product_id  from nova_market.products   where product_name like '%Dumbbell%'),
        (select payment_id  from nova_market.payments   order by payment_id limit 1 offset 2),
        (select point_id    from nova_market.pickup_points where point_number = '+77071100003'),
        '2026-03-03', '2026-03-07', 'On the way'),

    ('2026-01-26',
        (select customer_id from nova_market.customers  where last_name  = 'Nurov'),
        (select supplier_id from nova_market.suppliers  where supplier_name like '%PageTurner%'),
        (select product_id  from nova_market.products   where product_name like '%Clean Code%'),
        (select payment_id  from nova_market.payments   order by payment_id limit 1 offset 3),
        (select point_id    from nova_market.pickup_points where point_number = '+77071100004'),
        '2026-01-27', '2026-01-29', 'Delivered'),

    ('2026-02-21',
        (select customer_id from nova_market.customers  where last_name  = 'Dzhaksybekova'),
        (select supplier_id from nova_market.suppliers  where supplier_name like '%StyleHub%'),
        (select product_id  from nova_market.products   where product_name like '%Merino%'),
        (select payment_id  from nova_market.payments   order by payment_id limit 1 offset 4),
        (select point_id    from nova_market.pickup_points where point_number = '+77071100005'),
        '2026-02-22', '2026-02-26', 'Cancelled'),

    ('2026-03-16',
        (select customer_id from nova_market.customers  where last_name  = 'Mukanov'),
        (select supplier_id from nova_market.suppliers  where supplier_name like '%HomeBase%'),
        (select product_id  from nova_market.products   where product_name like '%Instant Pot%'),
        (select payment_id  from nova_market.payments   order by payment_id limit 1 offset 5),
        (select point_id    from nova_market.pickup_points where point_number = '+77071100006'),
        '2026-03-17', '2026-03-21', 'On the way');

-- back-fill order_id in payments now that orders rows exist
update nova_market.payments p
set order_id = o.order_id
from nova_market.orders o
where o.payment_id = p.payment_id;

commit;

-- ---- product_reviews ----
insert into nova_market.product_reviews (customer_id, product_id, review_text, review_rating) values
    ((select customer_id from nova_market.customers where last_name = 'Bekova'),
     (select product_id  from nova_market.products  where product_name like '%WH-1000%'),
     'Excellent noise cancellation, battery life is impressive. Totally worth it.', 4.8),

    ((select customer_id from nova_market.customers where last_name = 'Seitkali'),
     (select product_id  from nova_market.products  where product_name like '%Shrimp%'),
     'Shrimp arrived healthy, great starter kit for nano tanks.', 4.6),

    ((select customer_id from nova_market.customers where last_name = 'Nurov'),
     (select product_id  from nova_market.products  where product_name like '%Clean Code%'),
     'A must-read for any developer. Changed how I write and review code.', 5.0),

    ((select customer_id from nova_market.customers where last_name = 'Ivanova'),
     (select product_id  from nova_market.products  where product_name like '%Dumbbell%'),
     'Solid build quality, the adjustable mechanism is smooth. Good for home gym.', 4.5),

    ((select customer_id from nova_market.customers where last_name = 'Mukanov'),
     (select product_id  from nova_market.products  where product_name like '%Instant Pot%'),
     'Does everything it promises. Pressure cook mode is a game-changer.', 4.7);

-- ---- support_tickets ----
insert into nova_market.support_tickets (order_id, payment_id, staff_id, status) values
    ((select order_id   from nova_market.orders   where status = 'Cancelled' limit 1),
     (select payment_id from nova_market.payments order by payment_id limit 1 offset 4),
     (select staff_id   from nova_market.support_staff where last_name = 'Akhmetova'),
     'In progress'),

    ((select order_id   from nova_market.orders   where status = 'Delivered' order by order_id limit 1 offset 1),
     (select payment_id from nova_market.payments order by payment_id limit 1 offset 1),
     (select staff_id   from nova_market.support_staff where last_name = 'Petrov'),
     'Resolved'),

    ((select order_id   from nova_market.orders   where status = 'On the way' order by order_id limit 1),
     (select payment_id from nova_market.payments order by payment_id limit 1 offset 2),
     (select staff_id   from nova_market.support_staff where last_name = 'Smagulova'),
     'Not resolved'),

    ((select order_id   from nova_market.orders   where status = 'Delivered' order by order_id limit 1),
     (select payment_id from nova_market.payments order by payment_id limit 1),
     (select staff_id   from nova_market.support_staff where last_name = 'Yusupov'),
     'Closed'),

    ((select order_id   from nova_market.orders   where status = 'Delivered' order by order_id limit 1 offset 2),
     (select payment_id from nova_market.payments order by payment_id limit 1 offset 5),
     (select staff_id   from nova_market.support_staff where last_name = 'Bekzhanova'),
     'Not resolved');


-- ============================================================
-- PART C-7 — UPDATE: 2 business-event updates with SELECT previews
-- ============================================================

-- UPDATE 1: customer Daniyar moved — update his address and phone
-- preview rows being changed (count: 1)
select customer_id, first_name, last_name, address, phone_number
from nova_market.customers
where last_name = 'Seitkali';
-- row count: 1

update nova_market.customers
set    address      = 'Atyrau, ul. Satpaeva 99',
       phone_number = '+77012299999'
where  last_name    = 'Seitkali';


-- UPDATE 2: supplier AquaWorld got re-rated after quarterly review
-- preview rows being changed (count: 1)
select supplier_id, supplier_name, rating
from nova_market.suppliers
where supplier_name like '%AquaWorld%';
-- row count: 1

update nova_market.suppliers
set    rating = 4.9
where  supplier_name like '%AquaWorld%';


-- ============================================================
-- PART C-8 — UPDATE … FROM: mark products as low-stock (add sold-out flag)
-- ---- business context: orders table tells us actual sold units;
--      we raise the sale_count on products to match real order volume
-- ============================================================

-- preview: products that have at least one order placed against them
select p.product_id, p.product_name, p.sale_count, count(o.order_id) as order_count
from nova_market.products p
join nova_market.orders   o using (product_id)
group by p.product_id, p.product_name, p.sale_count;
-- row count: ~6 (one per ordered product)

update nova_market.products p
set    sale_count = p.sale_count + order_totals.cnt
from (
    select product_id, count(*) as cnt
    from   nova_market.orders
    group  by product_id
) as order_totals
where p.product_id = order_totals.product_id;


-- ============================================================
-- PART D-9 & D-10 — DELETE in transaction with ROLLBACK
-- ============================================================

-- business reason: cancelled orders that are older than the current date
-- serve no operational purpose — they clutter the orders table, inflate
-- pickup-point load reports, and slow down status-filter queries.
-- removing them keeps the active-order dataset clean.
-- (using ROLLBACK so this is safe to run during the exam)

begin;

delete from nova_market.orders
where status = 'Cancelled';

select count(*) from nova_market.orders;
-- row count after delete: 5  (was 6; 1 cancelled row removed)

rollback;

-- ============================================================
-- end of file
-- ============================================================
