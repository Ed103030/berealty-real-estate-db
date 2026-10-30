-- =====================================================================
-- Berealty Real Estate Property Management Database
-- File 1 of 5: schema (tables, constraints, indexes)
-- Requires MySQL 8.0.16 or later (CHECK constraints are enforced from 8.0.16)
-- WARNING: this script drops and recreates the berealty database.
-- =====================================================================

DROP DATABASE IF EXISTS berealty;
CREATE DATABASE berealty CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE berealty;

-- ---------------------------------------------------------------------
-- Reference tables
-- ---------------------------------------------------------------------
CREATE TABLE property_types (
    type_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    type_name    VARCHAR(50)  NOT NULL,
    segment      ENUM('Residential', 'Commercial') NOT NULL,
    description  VARCHAR(255),
    PRIMARY KEY (type_id),
    UNIQUE KEY uq_property_types_name (type_name)
) ENGINE = InnoDB;

CREATE TABLE districts (
    district_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
    district_name  VARCHAR(60)  NOT NULL,
    PRIMARY KEY (district_id),
    UNIQUE KEY uq_districts_name (district_name)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- People
-- ---------------------------------------------------------------------
CREATE TABLE agents (
    agent_id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
    first_name            VARCHAR(50)  NOT NULL,
    last_name             VARCHAR(50)  NOT NULL,
    email                 VARCHAR(100) NOT NULL,
    phone                 VARCHAR(20)  NOT NULL,
    hire_date             DATE         NOT NULL,
    base_commission_rate  DECIMAL(5,4) NOT NULL,          -- e.g. 0.0300 = 3.00 %
    is_active             BOOLEAN      NOT NULL DEFAULT TRUE,
    PRIMARY KEY (agent_id),
    UNIQUE KEY uq_agents_email (email),
    CONSTRAINT chk_agents_rate CHECK (base_commission_rate BETWEEN 0 AND 0.1000)
) ENGINE = InnoDB;

-- A client has no fixed role: seller/buyer is a role in a transaction, not an attribute of the person.
CREATE TABLE clients (
    client_id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    first_name         VARCHAR(50)  NOT NULL,
    last_name          VARCHAR(50)  NOT NULL,
    email              VARCHAR(100) NOT NULL,
    phone              VARCHAR(20)  NOT NULL,
    registration_date  DATE         NOT NULL,
    PRIMARY KEY (client_id),
    UNIQUE KEY uq_clients_email (email)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Properties
-- ---------------------------------------------------------------------
CREATE TABLE properties (
    property_id     INT UNSIGNED NOT NULL AUTO_INCREMENT,
    type_id         INT UNSIGNED NOT NULL,
    district_id     INT UNSIGNED NOT NULL,
    owner_id        INT UNSIGNED NOT NULL,                 -- current owner (changes when a sale completes)
    street_address  VARCHAR(255) NOT NULL,
    postal_code     CHAR(5)      NOT NULL,
    city            VARCHAR(100) NOT NULL DEFAULT 'Berlin',
    bedrooms        TINYINT UNSIGNED NULL,                 -- NULL for commercial space
    bathrooms       TINYINT UNSIGNED NULL,
    area_sqm        DECIMAL(8,2) NOT NULL,
    asking_price    DECIMAL(12,2) NOT NULL,
    status          ENUM('Available', 'Under Offer', 'Sold', 'Withdrawn') NOT NULL DEFAULT 'Available',
    listing_date    DATE         NOT NULL,                 -- date of the most recent listing
    PRIMARY KEY (property_id),
    CONSTRAINT fk_properties_type     FOREIGN KEY (type_id)     REFERENCES property_types (type_id),
    CONSTRAINT fk_properties_district FOREIGN KEY (district_id) REFERENCES districts (district_id),
    CONSTRAINT fk_properties_owner    FOREIGN KEY (owner_id)    REFERENCES clients (client_id),
    CONSTRAINT chk_properties_area    CHECK (area_sqm > 0),
    CONSTRAINT chk_properties_price   CHECK (asking_price > 0),
    CONSTRAINT chk_properties_postal  CHECK (postal_code REGEXP '^[0-9]{5}$'),
    KEY idx_properties_status_district (status, district_id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Transactions
-- ---------------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
    property_id       INT UNSIGNED NOT NULL,
    seller_id         INT UNSIGNED NOT NULL,               -- the owner at the time of sale (history)
    buyer_id          INT UNSIGNED NOT NULL,
    agent_id          INT UNSIGNED NOT NULL,
    transaction_date  DATE         NOT NULL,
    sale_price        DECIMAL(12,2) NOT NULL,
    commission_rate   DECIMAL(5,4) NOT NULL,               -- rate agreed for THIS deal
    commission_amount DECIMAL(12,2)
        GENERATED ALWAYS AS (ROUND(sale_price * commission_rate, 2)) STORED,
    status            ENUM('Pending', 'Completed', 'Cancelled') NOT NULL DEFAULT 'Pending',
    PRIMARY KEY (transaction_id),
    CONSTRAINT fk_transactions_property FOREIGN KEY (property_id) REFERENCES properties (property_id),
    CONSTRAINT fk_transactions_seller   FOREIGN KEY (seller_id)   REFERENCES clients (client_id),
    CONSTRAINT fk_transactions_buyer    FOREIGN KEY (buyer_id)    REFERENCES clients (client_id),
    CONSTRAINT fk_transactions_agent    FOREIGN KEY (agent_id)    REFERENCES agents (agent_id),
    CONSTRAINT chk_transactions_parties CHECK (seller_id <> buyer_id),
    CONSTRAINT chk_transactions_price   CHECK (sale_price > 0),
    CONSTRAINT chk_transactions_rate    CHECK (commission_rate BETWEEN 0 AND 0.1000),
    KEY idx_transactions_date_status (transaction_date, status),
    KEY idx_transactions_agent_date  (agent_id, transaction_date),
    KEY idx_transactions_property    (property_id),
    KEY idx_transactions_buyer       (buyer_id),
    KEY idx_transactions_seller      (seller_id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Viewings
-- ---------------------------------------------------------------------
CREATE TABLE property_viewings (
    viewing_id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    property_id       INT UNSIGNED NOT NULL,
    client_id         INT UNSIGNED NOT NULL,
    agent_id          INT UNSIGNED NOT NULL,
    viewing_datetime  DATETIME     NOT NULL,
    feedback          VARCHAR(500),
    interest_level    TINYINT UNSIGNED NOT NULL,           -- 1 (none) to 5 (very high)
    PRIMARY KEY (viewing_id),
    CONSTRAINT fk_viewings_property FOREIGN KEY (property_id) REFERENCES properties (property_id),
    CONSTRAINT fk_viewings_client   FOREIGN KEY (client_id)   REFERENCES clients (client_id),
    CONSTRAINT fk_viewings_agent    FOREIGN KEY (agent_id)    REFERENCES agents (agent_id),
    CONSTRAINT chk_viewings_interest CHECK (interest_level BETWEEN 1 AND 5),
    KEY idx_viewings_property_date (property_id, viewing_datetime),
    KEY idx_viewings_client (client_id),
    KEY idx_viewings_agent (agent_id)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- Audit tables (filled automatically by triggers, see file 3)
-- ---------------------------------------------------------------------
CREATE TABLE transaction_status_log (
    log_id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    transaction_id  INT UNSIGNED NOT NULL,
    old_status      VARCHAR(20)  NULL,
    new_status      VARCHAR(20)  NOT NULL,
    changed_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by      VARCHAR(100) NOT NULL,
    PRIMARY KEY (log_id),
    CONSTRAINT fk_statuslog_transaction FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id),
    KEY idx_statuslog_transaction (transaction_id)
) ENGINE = InnoDB;

CREATE TABLE property_price_history (
    history_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    property_id  INT UNSIGNED NOT NULL,
    old_price    DECIMAL(12,2) NOT NULL,
    new_price    DECIMAL(12,2) NOT NULL,
    changed_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (history_id),
    CONSTRAINT fk_pricehistory_property FOREIGN KEY (property_id) REFERENCES properties (property_id),
    KEY idx_pricehistory_property (property_id)
) ENGINE = InnoDB;