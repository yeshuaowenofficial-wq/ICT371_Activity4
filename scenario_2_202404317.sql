
DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS lab_sessions CASCADE;

CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    course_code VARCHAR(20) NOT NULL,
    available_workstations INT NOT NULL
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INT REFERENCES lab_sessions(session_id),
    lecturer_name VARCHAR(100) NOT NULL,
    num_workstations INT NOT NULL,
    status VARCHAR(20) DEFAULT 'RESERVED'
);

INSERT INTO lab_sessions (course_code, available_workstations) VALUES
('ICT371', 30),
('CS211', 5),
('ICT111', 0);

-- Step 2: IF ELSIF ELSE Control Structure
DO $$
DECLARE
    v_ws INT;
BEGIN
    SELECT available_workstations INTO v_ws FROM lab_sessions WHERE session_id = 1;
    IF v_ws = 0 THEN
        RAISE NOTICE 'Session is full.';
    ELSIF v_ws < 10 THEN
        RAISE NOTICE 'Session is nearly full.';
    ELSE
        RAISE NOTICE 'Session has enough workstations.';
    END IF;
END $$;

-- Step 3: WHILE and FOR Loops
DO $$
DECLARE
    v_cnt INT := 1;
BEGIN
    WHILE v_cnt <= 3 LOOP
        RAISE NOTICE 'Session preparation reminder #%', v_cnt;
        v_cnt := v_cnt + 1;
    END LOOP;

    FOR check_no IN 1..3 LOOP
        RAISE NOTICE 'Workstation check #%', check_no;
    END LOOP;
END $$;

-- Step 4: Procedure reserve_workstations
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INT,
    p_lecturer VARCHAR,
    p_num INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_avail INT;
BEGIN
    IF p_num <= 0 THEN
        RAISE EXCEPTION 'Invalid reservation amount: must request at least 1 workstation.';
    END IF;

    SELECT available_workstations INTO v_avail FROM lab_sessions WHERE session_id = p_session_id;

    IF v_avail < p_num THEN
        RAISE NOTICE 'Reservation Failed: % requested, but only % available.', p_num, v_avail;
    ELSE
        UPDATE lab_sessions 
        SET available_workstations = available_workstations - p_num 
        WHERE session_id = p_session_id;

        INSERT INTO reservations (session_id, lecturer_name, num_workstations, status)
        VALUES (p_session_id, p_lecturer, p_num, 'RESERVED');

        RAISE NOTICE 'Reservation successful for Dr./Mr. %', p_lecturer;
    END IF;
END $$;

-- Step 5: Execute test reservations
CALL reserve_workstations(1, 'Dr. Bandas', 10);
CALL reserve_workstations(2, 'Mrs. Chanda', 3);
CALL reserve_workstations(3, 'Mr. Phiri', 5); -- Exceeds capacity

SELECT * FROM lab_sessions;
SELECT * FROM reservations;

-- Step 6: Procedure cancel_reservation
CREATE OR REPLACE PROCEDURE cancel_reservation(p_res_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_sess_id INT;
    v_num INT;
BEGIN
    SELECT status, session_id, num_workstations INTO v_status, v_sess_id, v_num 
    FROM reservations WHERE reservation_id = p_res_id;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation % is already cancelled. Workstations not released again.', p_res_id;
    ELSIF v_status = 'RESERVED' THEN
        UPDATE lab_sessions 
        SET available_workstations = available_workstations + v_num 
        WHERE session_id = v_sess_id;

        UPDATE reservations 
        SET status = 'CANCELLED' 
        WHERE reservation_id = p_res_id;

        RAISE NOTICE 'Reservation % cancelled successfully.', p_res_id;
    END IF;
END $$;

-- Call cancel_reservation twice
CALL cancel_reservation(1);
CALL cancel_reservation(1);

-- Step 7: Explicit Cursor for sessions low on workstations
DO $$
DECLARE
    rec RECORD;
    cur_sessions CURSOR FOR 
        SELECT course_code, available_workstations FROM lab_sessions WHERE available_workstations < 10;
BEGIN
    OPEN cur_sessions;
    LOOP
        FETCH cur_sessions INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low Availability Session: % | Workstations Left: %', rec.course_code, rec.available_workstations;
    END LOOP;
    CLOSE cur_sessions;
END $$;

-- Step 8: Handle zero quantity with EXCEPTION
DO $$
BEGIN
    CALL reserve_workstations(1, 'Dr. Mulenga', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'EXCEPTION CAUGHT: %', SQLERRM;
END $$;

-- Step 9: Final Status Query
SELECT * FROM lab_sessions;
SELECT * FROM reservations;