-- =====================================================================
-- File 5 of 5: tests for the triggers, procedures and constraints
-- Run the blocks one at a time. Lines marked EXPECTED ERROR should fail with the message shown.
-- NOTE: the procedures COMMIT, so this file CHANGES the data.
-- To reset, re-run files 01, 02 and 03.
-- =====================================================================
USE berealty;

-- ---------------------------------------------------------------------
-- T1. Full sale: offer -> completion (property becomes Sold, ownership passes to the buyer)
-- ---------------------------------------------------------------------
CALL sp_register_offer(5, 14, 4, 340000.00, NULL);          -- agent 4's base rate is used
SET @tid = LAST_INSERT_ID();
SELECT property_id, status, owner_id FROM properties WHERE property_id = 5;       -- Under Offer, owner 1
CALL sp_close_transaction(@tid, 'Completed');
SELECT property_id, status, owner_id FROM properties WHERE property_id = 5;       -- Sold, owner 14
SELECT * FROM transaction_status_log WHERE transaction_id = @tid;                 -- NULL -> Pending, Pending -> Completed

-- ---------------------------------------------------------------------
-- T2. Cancelled offer: the property returns to the market
-- ---------------------------------------------------------------------
CALL sp_register_offer(11, 4, 3, 380000.00, 0.0300);
SET @tid2 = LAST_INSERT_ID();
SELECT property_id, status FROM properties WHERE property_id = 11;                -- Under Offer
CALL sp_close_transaction(@tid2, 'Cancelled');
SELECT property_id, status FROM properties WHERE property_id = 11;                -- Available

-- ---------------------------------------------------------------------
-- T3. Relisting a sold property at a new price (price history is recorded by a trigger)
-- ---------------------------------------------------------------------
CALL sp_relist_property(1, 520000.00);
SELECT property_id, status, asking_price FROM properties WHERE property_id = 1;   -- Available, 520000
SELECT * FROM property_price_history WHERE property_id = 1;                       -- 495000 -> 520000

-- ---------------------------------------------------------------------
-- T4. Business rules that must be rejected
-- ---------------------------------------------------------------------
-- EXPECTED ERROR: Seller is not the current owner of the property
INSERT INTO transactions (property_id, seller_id, buyer_id, agent_id, transaction_date, sale_price, commission_rate, status)
VALUES (14, 1, 2, 1, CURDATE(), 1000000.00, 0.0300, 'Pending');

-- EXPECTED ERROR: Property is not on the market: relist it with sp_relist_property first
CALL sp_register_offer(6, 2, 1, 1700000.00, NULL);

-- EXPECTED ERROR: Property already has a pending transaction
CALL sp_register_offer(12, 4, 1, 480000.00, NULL);

-- EXPECTED ERROR: Completed and cancelled transactions are read-only
UPDATE transactions SET sale_price = 1.00 WHERE transaction_id = 1;

-- EXPECTED ERROR: Only pending transactions can be closed
CALL sp_close_transaction(1, 'Cancelled');

-- EXPECTED ERROR: CHECK constraint violated (interest level must be 1 to 5)
INSERT INTO property_viewings (property_id, client_id, agent_id, viewing_datetime, feedback, interest_level)
VALUES (5, 1, 4, '2024-10-22 10:00:00', 'Invalid rating', 9);

-- EXPECTED ERROR: CHECK constraint violated (commission rate above 10 %)
INSERT INTO agents (first_name, last_name, email, phone, hire_date, base_commission_rate)
VALUES ('Test', 'Agent', 'test.agent@berealty.example', '+49 30 555 0199', '2024-10-01', 0.5000);

-- EXPECTED ERROR: foreign key prevents deleting a client who has transactions
DELETE FROM clients WHERE client_id = 1;

-- ---------------------------------------------------------------------
-- T5. Integrity audits: each query must return ZERO rows
-- ---------------------------------------------------------------------
-- Properties marked Under Offer without a pending transaction
SELECT p.property_id FROM properties p
WHERE p.status = 'Under Offer'
  AND NOT EXISTS (SELECT 1 FROM transactions t WHERE t.property_id = p.property_id AND t.status = 'Pending');

-- Pending transactions whose property is not Under Offer
SELECT t.transaction_id FROM transactions t
JOIN properties p ON p.property_id = t.property_id
WHERE t.status = 'Pending' AND p.status <> 'Under Offer';

-- Sold properties whose owner is not the buyer of the latest completed sale
SELECT p.property_id FROM properties p
JOIN transactions t ON t.property_id = p.property_id AND t.status = 'Completed'
WHERE p.status = 'Sold'
  AND t.transaction_date = (SELECT MAX(t2.transaction_date) FROM transactions t2
                            WHERE t2.property_id = p.property_id AND t2.status = 'Completed')
  AND p.owner_id <> t.buyer_id;