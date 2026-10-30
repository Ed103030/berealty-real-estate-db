-- =====================================================================
-- File 3 of 5: views, triggers and stored procedures
-- Run in MySQL Workbench or the mysql client (the DELIMITER lines are client commands).
-- =====================================================================
USE berealty;

-- ---------------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_available_properties AS
SELECT p.property_id,
       pt.type_name,
       pt.segment,
       d.district_name,
       p.street_address,
       p.postal_code,
       p.bedrooms,
       p.area_sqm,
       p.asking_price,
       ROUND(p.asking_price / p.area_sqm, 0) AS price_per_sqm,
       p.listing_date
FROM properties p
JOIN property_types pt ON pt.type_id = p.type_id
JOIN districts d       ON d.district_id = p.district_id
WHERE p.status = 'Available';

CREATE OR REPLACE VIEW v_completed_sales AS
SELECT t.transaction_id,
       t.transaction_date,
       p.property_id,
       pt.type_name,
       pt.segment,
       d.district_name,
       p.street_address,
       CONCAT(s.first_name, ' ', s.last_name) AS seller_name,
       CONCAT(b.first_name, ' ', b.last_name) AS buyer_name,
       CONCAT(a.first_name, ' ', a.last_name) AS agent_name,
       t.agent_id,
       t.sale_price,
       t.commission_rate,
       t.commission_amount
FROM transactions t
JOIN properties p       ON p.property_id = t.property_id
JOIN property_types pt  ON pt.type_id = p.type_id
JOIN districts d        ON d.district_id = p.district_id
JOIN clients s          ON s.client_id = t.seller_id
JOIN clients b          ON b.client_id = t.buyer_id
JOIN agents a           ON a.agent_id = t.agent_id
WHERE t.status = 'Completed';

-- ---------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------
DELIMITER $$

-- 1. Validate every new transaction before it is stored
CREATE TRIGGER trg_transactions_bi
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
    DECLARE v_owner   INT UNSIGNED;
    DECLARE v_status  VARCHAR(20);
    DECLARE v_pending INT;

    SELECT owner_id, status INTO v_owner, v_status
    FROM properties
    WHERE property_id = NEW.property_id;

    IF v_owner IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Property does not exist';
    END IF;

    IF NEW.seller_id <> v_owner THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller is not the current owner of the property';
    END IF;

    IF NEW.status <> 'Cancelled' THEN
        IF v_status IN ('Sold', 'Withdrawn') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Property is not on the market: relist it with sp_relist_property first';
        END IF;

        IF NEW.status = 'Pending' THEN
            SELECT COUNT(*) INTO v_pending
            FROM transactions
            WHERE property_id = NEW.property_id AND status = 'Pending';
            IF v_pending > 0 THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Property already has a pending transaction';
            END IF;
        END IF;
    END IF;
END$$

-- 2. After a transaction is created, update the property and write the audit log
CREATE TRIGGER trg_transactions_ai
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
    IF NEW.status = 'Pending' THEN
        UPDATE properties SET status = 'Under Offer' WHERE property_id = NEW.property_id;
    ELSEIF NEW.status = 'Completed' THEN
        UPDATE properties SET status = 'Sold', owner_id = NEW.buyer_id WHERE property_id = NEW.property_id;
    END IF;

    INSERT INTO transaction_status_log (transaction_id, old_status, new_status, changed_by)
    VALUES (NEW.transaction_id, NULL, NEW.status, CURRENT_USER());
END$$

-- 3. Completed and cancelled transactions are final
CREATE TRIGGER trg_transactions_bu
BEFORE UPDATE ON transactions
FOR EACH ROW
BEGIN
    IF OLD.status IN ('Completed', 'Cancelled') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Completed and cancelled transactions are read-only';
    END IF;
    IF NEW.property_id <> OLD.property_id OR NEW.seller_id <> OLD.seller_id OR NEW.buyer_id <> OLD.buyer_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Property, seller and buyer cannot be changed: cancel and create a new transaction';
    END IF;
END$$

-- 4. When a transaction is completed (or cancelled), update the property automatically
CREATE TRIGGER trg_transactions_au
AFTER UPDATE ON transactions
FOR EACH ROW
BEGIN
    IF NEW.status <> OLD.status THEN
        INSERT INTO transaction_status_log (transaction_id, old_status, new_status, changed_by)
        VALUES (NEW.transaction_id, OLD.status, NEW.status, CURRENT_USER());

        IF NEW.status = 'Completed' THEN
            -- the property is sold and ownership passes to the buyer
            UPDATE properties
            SET status = 'Sold', owner_id = NEW.buyer_id
            WHERE property_id = NEW.property_id;
        ELSEIF NEW.status = 'Cancelled' THEN
            -- the property returns to the market
            UPDATE properties
            SET status = 'Available'
            WHERE property_id = NEW.property_id AND status = 'Under Offer';
        END IF;
    END IF;
END$$

-- 5. Keep a history of asking-price changes
CREATE TRIGGER trg_properties_price_au
AFTER UPDATE ON properties
FOR EACH ROW
BEGIN
    IF NEW.asking_price <> OLD.asking_price THEN
        INSERT INTO property_price_history (property_id, old_price, new_price)
        VALUES (NEW.property_id, OLD.asking_price, NEW.asking_price);
    END IF;
END$$

-- ---------------------------------------------------------------------
-- Stored procedures
-- ---------------------------------------------------------------------

-- Register an offer: locks the property row so two agents cannot sell the same property at once.
-- If p_rate is NULL the agent's base commission rate is used.
CREATE PROCEDURE sp_register_offer(
    IN p_property_id INT UNSIGNED,
    IN p_buyer_id    INT UNSIGNED,
    IN p_agent_id    INT UNSIGNED,
    IN p_price       DECIMAL(12,2),
    IN p_rate        DECIMAL(5,4)
)
BEGIN
    DECLARE v_owner  INT UNSIGNED;
    DECLARE v_new_id INT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT owner_id INTO v_owner
    FROM properties
    WHERE property_id = p_property_id
    FOR UPDATE;

    INSERT INTO transactions
        (property_id, seller_id, buyer_id, agent_id, transaction_date, sale_price, commission_rate, status)
    VALUES
        (p_property_id, v_owner, p_buyer_id, p_agent_id, CURDATE(), p_price,
         COALESCE(p_rate, (SELECT base_commission_rate FROM agents WHERE agent_id = p_agent_id)),
         'Pending');
    SET v_new_id = LAST_INSERT_ID();

    COMMIT;
    SELECT v_new_id AS new_transaction_id;
END$$

-- Complete or cancel a pending transaction (the triggers update the property)
CREATE PROCEDURE sp_close_transaction(
    IN p_transaction_id INT UNSIGNED,
    IN p_outcome        VARCHAR(10)          -- 'Completed' or 'Cancelled'
)
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_outcome NOT IN ('Completed', 'Cancelled') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Outcome must be Completed or Cancelled';
    END IF;

    START TRANSACTION;

    SELECT status INTO v_status
    FROM transactions
    WHERE transaction_id = p_transaction_id
    FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transaction not found';
    END IF;
    IF v_status <> 'Pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only pending transactions can be closed';
    END IF;

    UPDATE transactions SET status = p_outcome WHERE transaction_id = p_transaction_id;

    COMMIT;
END$$

-- Put a sold or withdrawn property back on the market (new owner relists)
CREATE PROCEDURE sp_relist_property(
    IN p_property_id INT UNSIGNED,
    IN p_new_price   DECIMAL(12,2)
)
BEGIN
    DECLARE v_status VARCHAR(20);

    SELECT status INTO v_status FROM properties WHERE property_id = p_property_id;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Property does not exist';
    END IF;
    IF v_status NOT IN ('Sold', 'Withdrawn') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only sold or withdrawn properties can be relisted';
    END IF;

    UPDATE properties
    SET status = 'Available', asking_price = p_new_price, listing_date = CURDATE()
    WHERE property_id = p_property_id;
END$$

-- Yearly agent performance report with ranking
CREATE PROCEDURE sp_agent_report(IN p_year INT)
BEGIN
    SELECT a.agent_id,
           CONCAT(a.first_name, ' ', a.last_name)  AS agent,
           COUNT(t.transaction_id)                 AS completed_deals,
           COALESCE(SUM(t.sale_price), 0)          AS revenue,
           COALESCE(SUM(t.commission_amount), 0)   AS commission,
           RANK() OVER (ORDER BY COALESCE(SUM(t.sale_price), 0) DESC) AS revenue_rank
    FROM agents a
    LEFT JOIN transactions t
           ON t.agent_id = a.agent_id
          AND t.status = 'Completed'
          AND t.transaction_date >= MAKEDATE(p_year, 1)
          AND t.transaction_date <  MAKEDATE(p_year + 1, 1)
    GROUP BY a.agent_id, a.first_name, a.last_name
    ORDER BY revenue_rank, agent;
END$$

DELIMITER ;