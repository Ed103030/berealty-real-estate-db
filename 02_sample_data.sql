-- =====================================================================
-- File 2 of 5: sample data (all names, addresses and e-mails are fictional)
-- Loaded BEFORE the triggers exist, so statuses and owners are set by hand
-- and are consistent with the transaction history.
-- =====================================================================
USE berealty;

INSERT INTO property_types (type_name, segment, description) VALUES
('Apartment',     'Residential', 'Flat in a multi-unit building'),
('Penthouse',     'Residential', 'Top-floor luxury apartment'),
('Studio',        'Residential', 'Single-room apartment'),
('Townhouse',     'Residential', 'Multi-storey terraced house'),
('Villa',         'Residential', 'Detached house with garden'),
('Office',        'Commercial',  'Office space'),
('Retail Unit',   'Commercial',  'Ground-floor shop'),
('Warehouse',     'Commercial',  'Storage and logistics space'),
('Parking Space', 'Commercial',  'Garage or parking bay');

INSERT INTO districts (district_name) VALUES
('Mitte'), ('Charlottenburg-Wilmersdorf'), ('Friedrichshain-Kreuzberg'), ('Pankow'),
('Neukölln'), ('Tempelhof-Schöneberg'), ('Steglitz-Zehlendorf'), ('Lichtenberg');

INSERT INTO agents (first_name, last_name, email, phone, hire_date, base_commission_rate, is_active) VALUES
('Anna',   'Weber',   'anna.weber@berealty.example',   '+49 30 555 0101', '2018-03-01', 0.0300, TRUE),
('Jonas',  'Keller',  'jonas.keller@berealty.example', '+49 30 555 0102', '2019-07-15', 0.0325, TRUE),
('Mira',   'Hoffmann','mira.hoffmann@berealty.example','+49 30 555 0103', '2020-02-01', 0.0300, TRUE),
('Lukas',  'Brandt',  'lukas.brandt@berealty.example', '+49 30 555 0104', '2021-09-01', 0.0275, TRUE),
('Sofia',  'Richter', 'sofia.richter@berealty.example','+49 30 555 0105', '2022-04-11', 0.0300, TRUE),
('Tobias', 'Neumann', 'tobias.neumann@berealty.example','+49 30 555 0106','2023-06-01', 0.0250, TRUE);

INSERT INTO clients (first_name, last_name, email, phone, registration_date) VALUES
('Lena',   'Fischer',    'lena.fischer@mail.example',    '+49 151 555 0201', '2022-11-05'),
('Markus', 'Becker',     'markus.becker@mail.example',   '+49 151 555 0202', '2022-12-14'),
('Julia',  'Schneider',  'julia.schneider@mail.example', '+49 151 555 0203', '2023-01-09'),
('Daniel', 'Wolf',       'daniel.wolf@mail.example',     '+49 151 555 0204', '2023-02-01'),
('Emma',   'Schulz',     'emma.schulz@mail.example',     '+49 151 555 0205', '2023-03-18'),
('Felix',  'Braun',      'felix.braun@mail.example',     '+49 151 555 0206', '2022-12-20'),
('Hannah', 'Krüger',     'hannah.krueger@mail.example',  '+49 151 555 0207', '2023-01-30'),
('Paul',   'Lehmann',    'paul.lehmann@mail.example',    '+49 151 555 0208', '2023-04-02'),
('Clara',  'Zimmermann', 'clara.zimmermann@mail.example','+49 151 555 0209', '2023-05-11'),
('Leon',   'Hartmann',   'leon.hartmann@mail.example',   '+49 151 555 0210', '2023-06-06'),
('Nina',   'Vogel',      'nina.vogel@mail.example',      '+49 151 555 0211', '2023-08-23'),
('Max',    'Schröder',   'max.schroeder@mail.example',   '+49 151 555 0212', '2023-09-15'),
('Laura',  'König',      'laura.koenig@mail.example',    '+49 151 555 0213', '2024-01-08'),
('Ben',    'Jung',       'ben.jung@mail.example',        '+49 151 555 0214', '2024-02-19'),
('Sarah',  'Meyer',      'sarah.meyer@mail.example',     '+49 151 555 0215', '2024-03-27'),
('Tim',    'Albrecht',   'tim.albrecht@mail.example',    '+49 151 555 0216', '2024-05-04');

-- owner_id is the CURRENT owner (the buyer of the latest completed sale, where one exists)
INSERT INTO properties
(type_id, district_id, owner_id, street_address, postal_code, bedrooms, bathrooms, area_sqm, asking_price, status, listing_date) VALUES
(1, 1,  6, 'Musterstraße 12',   '10115', 2,    1, 68.50,  495000.00, 'Sold',        '2023-01-10'),
(2, 2,  7, 'Beispielallee 4',   '10585', 3,    2, 142.00, 1290000.00,'Sold',        '2023-02-20'),
(3, 3, 13, 'Probeweg 21',       '10243', 1,    1, 32.00,  359000.00, 'Sold',        '2024-03-20'),
(4, 4,  9, 'Demostraße 9',      '10405', 4,    2, 165.00, 920000.00, 'Sold',        '2023-07-25'),
(1, 5,  1, 'Testplatz 3',       '12043', 2,    1, 59.00,  349000.00, 'Available',   '2024-01-20'),
(6, 1, 10, 'Musterring 8',      '10117', NULL, 2, 210.00, 1790000.00,'Sold',        '2023-09-01'),
(7, 3, 11, 'Beispielgasse 15',  '10961', NULL, 1, 95.00,  960000.00, 'Sold',        '2023-11-10'),
(1, 6, 12, 'Probeallee 6',      '10827', 3,    1, 84.00,  575000.00, 'Sold',        '2024-01-12'),
(5, 7, 14, 'Demoweg 2',         '14163', 6,    4, 310.00, 2490000.00,'Sold',        '2024-03-30'),
(8, 8, 15, 'Musterhof 30',      '10365', NULL, 2, 780.00, 1350000.00,'Sold',        '2024-05-02'),
(1, 4,  2, 'Testweg 18',        '10405', 2,    1, 64.00,  389000.00, 'Available',   '2024-06-01'),
(1, 1,  3, 'Beispielplatz 5',   '10117', 2,    1, 71.00,  495000.00, 'Under Offer', '2024-08-20'),
(2, 1,  4, 'Musterturm 1',      '10178', 4,    3, 175.00, 2050000.00,'Under Offer', '2024-08-25'),
(6, 2,  5, 'Probestraße 40',    '10585', NULL, 2, 240.00, 1150000.00,'Available',   '2024-06-15'),
(3, 5,  5, 'Demoallee 11',      '12043', 1,    1, 28.00,  305000.00, 'Sold',        '2024-08-10'),
(4, 7,  7, 'Testhof 7',         '14163', 4,    3, 150.00, 1090000.00,'Available',   '2024-09-18'),
(7, 1,  8, 'Musterpassage 3',   '10115', NULL, 1, 120.00, 1380000.00,'Available',   '2024-08-15'),
(1, 3,  9, 'Beispielufer 9',    '10243', 3,    2, 92.00,  645000.00, 'Available',   '2024-09-25'),
(6, 8, 10, 'Probering 22',      '10365', NULL, 3, 330.00, 1480000.00,'Available',   '2024-10-01'),
(1, 2, 11, 'Demoplatz 14',      '10585', 2,    1, 66.00,  449000.00, 'Available',   '2024-10-05');

-- commission_amount is generated automatically from sale_price and commission_rate
INSERT INTO transactions
(property_id, seller_id, buyer_id, agent_id, transaction_date, sale_price, commission_rate, status) VALUES
(1,  1,  6, 1, '2023-02-14',  485000.00, 0.0300, 'Completed'),
(2,  2,  7, 2, '2023-04-20', 1250000.00, 0.0325, 'Completed'),
(3,  3,  8, 1, '2023-06-30',  320000.00, 0.0300, 'Completed'),
(4,  4,  9, 3, '2023-09-12',  890000.00, 0.0300, 'Completed'),
(6,  5, 10, 4, '2023-11-03', 1750000.00, 0.0275, 'Completed'),
(7,  2, 11, 2, '2024-01-25',  940000.00, 0.0325, 'Completed'),
(8,  3, 12, 5, '2024-03-08',  560000.00, 0.0300, 'Completed'),
(3,  8, 13, 3, '2024-04-18',  355000.00, 0.0300, 'Completed'),   -- resale of property 3
(9,  4, 14, 1, '2024-05-29', 2400000.00, 0.0300, 'Completed'),
(10, 5, 15, 4, '2024-07-16', 1320000.00, 0.0275, 'Completed'),
(14, 5, 12, 3, '2024-08-20', 1100000.00, 0.0300, 'Cancelled'),   -- financing fell through
(15,16,  5, 5, '2024-10-02',  298000.00, 0.0300, 'Completed'),
(12, 3,  2, 6, '2024-10-10',  489000.00, 0.0250, 'Pending'),
(13, 4, 16, 2, '2024-10-18', 1980000.00, 0.0325, 'Pending');

INSERT INTO property_viewings (property_id, client_id, agent_id, viewing_datetime, feedback, interest_level) VALUES
(1,  6, 1, '2023-01-20 10:00:00', 'Bright flat, very interested', 5),
(1,  7, 1, '2023-01-22 14:30:00', 'Too expensive', 2),
(2,  7, 2, '2023-03-18 11:00:00', 'Loved the terrace', 5),
(2,  9, 2, '2023-03-25 16:00:00', 'Wants a larger kitchen', 3),
(3,  8, 1, '2023-05-27 09:30:00', 'Good first purchase', 4),
(4,  9, 3, '2023-08-05 15:00:00', 'Garden is perfect', 5),
(4, 10, 3, '2023-08-06 12:00:00', 'Noisy street', 2),
(5,  2, 4, '2024-02-10 10:00:00', 'Needs renovation', 3),
(5, 13, 5, '2024-03-02 13:00:00', 'Interested, financing check needed', 4),
(5, 14, 5, '2024-05-14 17:00:00', 'Too small', 2),
(6, 10, 4, '2023-10-05 10:30:00', 'Ideal office location', 5),
(7, 11, 2, '2023-12-15 11:30:00', 'Strong footfall', 4),
(8, 12, 5, '2024-02-02 14:00:00', 'Quiet courtyard', 4),
(9, 14, 1, '2024-04-20 15:30:00', 'Dream home', 5),
(9, 15, 1, '2024-04-27 11:00:00', 'Price above budget', 2),
(10,15, 4, '2024-06-10 09:00:00', 'Good logistics access', 4),
(11, 3, 3, '2024-06-22 10:00:00', 'Nice balcony', 4),
(11,16, 3, '2024-07-03 18:00:00', 'Too far from work', 2),
(12, 2, 6, '2024-09-14 12:00:00', 'Offer planned', 5),
(13,16, 2, '2024-09-28 16:30:00', 'Impressive views', 5),
(14,12, 3, '2024-08-01 10:00:00', 'Interested, financing fell through', 3),
(14, 6, 3, '2024-09-15 11:00:00', 'Too big', 1),
(15, 5, 5, '2024-09-01 13:30:00', 'Perfect starter flat', 5),
(17,13, 2, '2024-09-05 10:30:00', 'Needs fit-out budget', 3),
(18, 1, 6, '2024-10-12 15:00:00', 'Liked it, wants a second viewing', 4);

-- Back-fill the status log for the loaded transactions
INSERT INTO transaction_status_log (transaction_id, old_status, new_status, changed_at, changed_by)
SELECT transaction_id, NULL, status, CONCAT(transaction_date, ' 09:00:00'), 'initial data load'
FROM transactions;