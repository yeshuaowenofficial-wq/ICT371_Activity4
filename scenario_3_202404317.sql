-- Step 1: Create Tables & Insert Data
DROP TABLE IF EXISTS allocations CASCADE;
DROP TABLE IF EXISTS hostel_rooms CASCADE;

CREATE TABLE hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(10) NOT NULL,
    available_spaces INT NOT NULL
);

CREATE TABLE allocations (
    allocation_id SERIAL PRIMARY KEY,
    student_number VARCHAR(20) NOT NULL,
    room_id INT REFERENCES hostel_rooms(room_id),
    status VARCHAR(20) DEFAULT 'ALLOCATED'
);

INSERT INTO hostel_rooms (room_number, available_spaces) VALUES
('BlockA-101', 3),
('BlockA-102', 1),
('BlockB-201', 0);

-- Step 2: IF ELSIF ELSE Control Structure
DO $$
DECLARE
    v_spaces INT;
BEGIN
    SELECT available_spaces INTO v_spaces FROM hostel_rooms WHERE room_id = 1;
    IF v_spaces = 0 THEN
        RAISE NOTICE 'Room is full.';
    ELSIF v_spaces = 1 THEN
        RAISE NOTICE 'Room has one space left.';
    ELSE
        RAISE NOTICE 'Room has several spaces.';
    END IF;
END $$;

-- Step 3: WHILE and FOR Loops
DO $$
DECLARE
    v_day INT := 1;
BEGIN
    WHILE v_day <= 3 LOOP
        RAISE NOTICE 'Hostel Inspection Day %', v_day;
        v_day := v_day + 1;
    END LOOP;

    FOR r IN 1..3 LOOP
        RAISE NOTICE 'Room Check #%', r;
    END LOOP;
END $$;

-- Step 4: Procedure allocate_room
CREATE OR REPLACE PROCEDURE allocate_room(
    p_student_number VARCHAR,
    p_room_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_spaces INT;
BEGIN
    IF p_student_number IS NULL OR TRIM(p_student_number) = '' THEN
        RAISE EXCEPTION 'Student number cannot be blank.';
    END IF;

    SELECT available_spaces INTO v_spaces FROM hostel_rooms WHERE room_id = p_room_id;

    IF v_spaces <= 0 THEN
        RAISE NOTICE 'Allocation Failed: Room ID % is full.', p_room_id;
    ELSE
        UPDATE hostel_rooms 
        SET available_spaces = available_spaces - 1 
        WHERE room_id = p_room_id;

        INSERT INTO allocations (student_number, room_id, status)
        VALUES (p_student_number, p_room_id, 'ALLOCATED');

        RAISE NOTICE 'Space allocated to student % in Room ID %', p_student_number, p_room_id;
    END IF;
END $$;

-- Step 5: Execute allocations
CALL allocate_room('20220101', 1);
CALL allocate_room('20220102', 2);
CALL allocate_room('20220103', 3); -- Full room

SELECT * FROM hostel_rooms;
SELECT * FROM allocations;

-- Step 6: Procedure check_out
CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_room_id INT;
BEGIN
    SELECT status, room_id INTO v_status, v_room_id 
    FROM allocations WHERE allocation_id = p_allocation_id;

    IF v_status = 'COMPLETED' THEN
        RAISE NOTICE 'Allocation % is already completed. Bed space not freed again.', p_allocation_id;
    ELSIF v_status = 'ALLOCATED' THEN
        UPDATE hostel_rooms 
        SET available_spaces = available_spaces + 1 
        WHERE room_id = v_room_id;

        UPDATE allocations 
        SET status = 'COMPLETED' 
        WHERE allocation_id = p_allocation_id;

        RAISE NOTICE 'Check-out completed for allocation %.', p_allocation_id;
    END IF;
END $$;

-- Call check_out twice
CALL check_out(1);
CALL check_out(1);

-- Step 7: Explicit Cursor for full or nearly full rooms
DO $$
DECLARE
    rec RECORD;
    cur_rooms CURSOR FOR 
        SELECT room_number, available_spaces FROM hostel_rooms WHERE available_spaces <= 1;
BEGIN
    OPEN cur_rooms;
    LOOP
        FETCH cur_rooms INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full/Nearly Full Room: % | Spaces Left: %', rec.room_number, rec.available_spaces;
    END LOOP;
    CLOSE cur_rooms;
END $$;

-- Step 8: Handle blank student number with EXCEPTION
DO $$
BEGIN
    CALL allocate_room('', 1);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'EXCEPTION CAUGHT: %', SQLERRM;
END $$;

-- Step 9: Final Status Query
SELECT * FROM hostel_rooms;
SELECT * FROM allocations;