-- Step 1: Create Tables & Insert Data
DROP TABLE IF EXISTS dispensing_records CASCADE;
DROP TABLE IF EXISTS medicines CASCADE;

CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    stock_quantity INT NOT NULL
);

CREATE TABLE dispensing_records (
    dispense_id SERIAL PRIMARY KEY,
    medicine_id INT REFERENCES medicines(medicine_id),
    student_number VARCHAR(20) NOT NULL,
    quantity INT NOT NULL,
    status VARCHAR(20) DEFAULT 'DISPENSED'
);

INSERT INTO medicines (name, stock_quantity) VALUES
('Paracetamol 500mg', 50),
('Amoxicillin 250mg', 4),
('Ibuprofen 400mg', 0);

-- Step 2: IF ELSIF ELSE Control Structure
DO $$
DECLARE
    v_stock INT;
BEGIN
    SELECT stock_quantity INTO v_stock FROM medicines WHERE medicine_id = 1;
    IF v_stock = 0 THEN
        RAISE NOTICE 'Medicine is out of stock.';
    ELSIF v_stock < 10 THEN
        RAISE NOTICE 'Medicine is low on stock.';
    ELSE
        RAISE NOTICE 'Medicine is sufficiently stocked.';
    END IF;
END $$;

-- Step 3: WHILE and FOR Loops
DO $$
DECLARE
    v_rev INT := 1;
BEGIN
    WHILE v_rev <= 3 LOOP
        RAISE NOTICE 'Stock review day %', v_rev;
        v_rev := v_rev + 1;
    END LOOP;

    FOR s IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection #%', s;
    END LOOP;
END $$;

-- Step 4: Procedure dispense_medicine
CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id INT,
    p_student_number VARCHAR,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: Dispense quantity must be greater than zero.';
    END IF;

    SELECT stock_quantity INTO v_stock FROM medicines WHERE medicine_id = p_medicine_id;

    IF v_stock < p_quantity THEN
        RAISE NOTICE 'Dispensing Failed: Insufficient stock for Medicine ID %.', p_medicine_id;
    ELSE
        UPDATE medicines 
        SET stock_quantity = stock_quantity - p_quantity 
        WHERE medicine_id = p_medicine_id;

        INSERT INTO dispensing_records (medicine_id, student_number, quantity, status)
        VALUES (p_medicine_id, p_student_number, p_quantity, 'DISPENSED');

        RAISE NOTICE 'Dispensed % units to Student %', p_quantity, p_student_number;
    END IF;
END $$;

-- Step 5: Execute dispensing actions
CALL dispense_medicine(1, '20230010', 5);
CALL dispense_medicine(2, '20230011', 2);
CALL dispense_medicine(3, '20230012', 10); -- Exceeds stock

SELECT * FROM medicines;
SELECT * FROM dispensing_records;

-- Step 6: Procedure reverse_dispensing
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_dispense_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_med_id INT;
    v_qty INT;
BEGIN
    SELECT status, medicine_id, quantity INTO v_status, v_med_id, v_qty 
    FROM dispensing_records WHERE dispense_id = p_dispense_id;

    IF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Record % is already reversed. Stock not restored again.', p_dispense_id;
    ELSIF v_status = 'DISPENSED' THEN
        UPDATE medicines 
        SET stock_quantity = stock_quantity + v_qty 
        WHERE medicine_id = v_med_id;

        UPDATE dispensing_records 
        SET status = 'REVERSED' 
        WHERE dispense_id = p_dispense_id;

        RAISE NOTICE 'Dispensing record % reversed successfully.', p_dispense_id;
    END IF;
END $$;

-- Call reverse_dispensing twice
CALL reverse_dispensing(1);
CALL reverse_dispensing(1);

-- Step 7: Explicit Cursor for low stock medicines
DO $$
DECLARE
    rec RECORD;
    cur_low_meds CURSOR FOR 
        SELECT name, stock_quantity FROM medicines WHERE stock_quantity < 10;
BEGIN
    OPEN cur_low_meds;
    LOOP
        FETCH cur_low_meds INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low Stock Medicine: % | Stock Left: %', rec.name, rec.stock_quantity;
    END LOOP;
    CLOSE cur_low_meds;
END $$;

-- Step 8: Handle negative dispensing quantity with EXCEPTION
DO $$
BEGIN
    CALL dispense_medicine(1, '20230015', -2);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'EXCEPTION CAUGHT: %', SQLERRM;
END $$;

-- Step 9: Final Status Query
SELECT * FROM medicines;
SELECT * FROM dispensing_records;