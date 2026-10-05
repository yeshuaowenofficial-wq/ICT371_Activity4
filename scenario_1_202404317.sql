-- Step 1: Create Tables & Insert Data
DROP TABLE IF EXISTS book_loans CASCADE;
DROP TABLE IF EXISTS books CASCADE;

CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    available_copies INT NOT NULL
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    book_id INT REFERENCES books(book_id),
    student_number VARCHAR(20) NOT NULL,
    quantity INT NOT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE'
);

INSERT INTO books (title, available_copies) VALUES
('Database System Concepts', 5),
('Operating System Concepts', 1),
('Introduction to Algorithms', 0);

-- Step 2: IF ELSIF ELSE Control Structure
DO $$
DECLARE
    v_copies INT;
BEGIN
    SELECT available_copies INTO v_copies FROM books WHERE book_id = 1;
    IF v_copies = 0 THEN
        RAISE NOTICE 'Book is unavailable.';
    ELSIF v_copies < 3 THEN
        RAISE NOTICE 'Book is low on copies.';
    ELSE
        RAISE NOTICE 'Book is sufficiently stocked.';
    END IF;
END $$;

-- Step 3: WHILE and FOR Loops
DO $$
DECLARE
    v_counter INT := 1;
BEGIN
    -- WHILE loop for overdue reminder numbers
    WHILE v_counter <= 3 LOOP
        RAISE NOTICE 'Overdue Reminder #%', v_counter;
        v_counter := v_counter + 1;
    END LOOP;

    -- Numeric FOR loop for shelf numbers
    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Library Shelf Number: %', i;
    END LOOP;
END $$;

-- Step 4: Procedure borrow_book
CREATE OR REPLACE PROCEDURE borrow_book(
    p_book_id INT,
    p_student_number VARCHAR,
    p_quantity INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: must borrow at least 1 book.';
    END IF;

    SELECT available_copies INTO v_available FROM books WHERE book_id = p_book_id;

    IF v_available IS NULL THEN
        RAISE EXCEPTION 'Book ID % does not exist.', p_book_id;
    ELSIF v_available < p_quantity THEN
        RAISE NOTICE 'Loan Failed: Requested % copies, but only % available for Book ID %.', p_quantity, v_available, p_book_id;
    ELSE
        UPDATE books 
        SET available_copies = available_copies - p_quantity 
        WHERE book_id = p_book_id;

        INSERT INTO book_loans (book_id, student_number, quantity, status)
        VALUES (p_book_id, p_student_number, p_quantity, 'ISSUED');
        
        RAISE NOTICE 'Loan successful for Student %', p_student_number;
    END IF;
END $$;

-- Step 5: Call borrow_book with 2 valid and 1 excessive request
CALL borrow_book(1, '20210001', 2); -- Valid
CALL borrow_book(2, '20210002', 1); -- Valid
CALL borrow_book(3, '20210003', 2); -- Exceeds capacity

SELECT * FROM books;
SELECT * FROM book_loans;

-- Step 6: Procedure return_book (Idempotent return check)
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_book_id INT;
    v_qty INT;
BEGIN
    SELECT status, book_id, quantity INTO v_status, v_book_id, v_qty 
    FROM book_loans WHERE loan_id = p_loan_id;

    IF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan % is already returned. No copies restored.', p_loan_id;
    ELSIF v_status = 'ISSUED' THEN
        UPDATE books 
        SET available_copies = available_copies + v_qty 
        WHERE book_id = v_book_id;

        UPDATE book_loans 
        SET status = 'RETURNED' 
        WHERE loan_id = p_loan_id;

        RAISE NOTICE 'Loan % successfully returned and stock restored.', p_loan_id;
    ELSE
        RAISE NOTICE 'Invalid loan record.';
    END IF;
END $$;

-- Call return_book twice for the same loan
CALL return_book(1);
CALL return_book(1);

-- Step 7: Explicit Cursor for books low on copies
DO $$
DECLARE
    rec RECORD;
    cur_low_books CURSOR FOR 
        SELECT title, available_copies FROM books WHERE available_copies < 3;
BEGIN
    OPEN cur_low_books;
    LOOP
        FETCH cur_low_books INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Low Stock Book: "%" | Copies Left: %', rec.title, rec.available_copies;
    END LOOP;
    CLOSE cur_low_books;
END $$;

-- Step 8: Handle zero borrowing quantity with EXCEPTION
DO $$
BEGIN
    CALL borrow_book(1, '20210004', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'EXCEPTION CAUGHT: %', SQLERRM;
END $$;

-- Step 9: Final Status Query
SELECT * FROM books;
SELECT * FROM book_loans;