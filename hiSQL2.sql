
-- Key Concepts Covered :  Built-in data types, casting, string data type, numeric data type, 
-- date / time / timestamps, intervals, user defined data types, bit strings, blobs, bit arrays,

----------------------------------------------------------------------------------------------------
-- PostgreSQL built-in data types, CAST, casting text literals
----------------------------------------------------------------------------------------------------

-- Query the PostgreSQL system catalog for the supported data types:

SELECT t.typname
FROM   pg_catalog.pg_type AS t
WHERE  t.typelem  = 0      -- disregard array element types
AND  t.typrelid = 0;     -- list non-composite types only

-- Create a table T

DROP TABLE IF EXISTS T;

CREATE TABLE T (a int PRIMARY KEY,
                b text,
                c boolean,
                d int);

INSERT INTO T VALUES
  (1, 'x',  true, 10),
  (2, 'y',  true, 40),
  (3, 'x', false, 30),
  (4, 'y', false, 20),
  (5, 'x',  true, NULL);

-- CAST Operator :  Converts value of one type to another.

-- Syntaxes :

-- 1) CAST (<type1> AS  <type2>)
-- 2) <type1> :: <type2>
-- 3) <type2>(<type1>)

-- SQL performs implicit casts when the column types are unambiguous. 
-- (Say on of the columns during insertion has value null for a record). 
-- Type casting can fail at runtime in certain cases.
-- SQL also supports casting complex literals(text to json, date, csv etc.)

-- (Implicit) Type casts

-- Runtime type conversion
SELECT 6.2 :: int;          -- ➝ 6
SELECT 6.6 :: int;          -- ➝ 7
SELECT date('May 4, 2020'); -- ➝ 2020-05-04 (May the Force ...)

-- Implicit conversion if target type is known (here: schema of T)
INSERT INTO T(a,b,c,d) VALUES (6.2, NULL, 'true', '0');
--                              ↑     ↑      ↑     ↑
--                             int  text  boolean int


-- Literal input syntax using '...' (cast from text to any other type):

SELECT booleans.yup :: boolean, booleans.nope :: boolean
FROM   (VALUES ('true', 'false'),
               ('True', 'False'),
               ('t',    'f'), -- any prefix of 'true'/'false' is OK (whitespace, case do not matter)
               ('1',    '0'),
               ('yes',  'no'),
               ('on',   'off')) AS booleans(yup, nope);



-- The result of each of the records would be true or false since we're casting the literals.

-- May use $‹id›$...$‹id›$ instead of '...'
SELECT $$<t a='42'><l/><r/></t>$$ :: xml;

-- Type casts perform computation, validity checks, and thus are *not* for free:
SELECT $$<t a='42'><l/><r></t>$$ :: xml;
--                      ↑
--              ⚠ no closing tag

-- Implicit cast from text to target during *input conversion*:
DELETE FROM T;

COPY T(a,b,c,d) FROM STDIN WITH (FORMAT CSV, NULL '▢');
1,x,true,10
2,y,true,40
3,x,false,30
4,y,false,20
5,x,true,▢
\.

TABLE T;

----------------------------------------------------------------------------------------------------
-- String data types (char/varchar/text), type numeric(s,p)
----------------------------------------------------------------------------------------------------

-- Text Data types: char, varchar, text

SELECT '01234' :: char(3);   -- truncation to enforce limit after cast
--     └──┬──┘               -- NB: column name is `bpchar': blank-padded characters,
--      text                 --     PostgreSQL-internal name for char(‹n›)


-- The length limits are measured in characters and not in bytes (PostgreSQL: max size is approx 1 Gb). 
-- Excess characters might yield run time errors. Also, while explicit casting, the length might be 
-- truncated to the max length of desired data type.
-- text data type is used over char due to the weird behaviour of char data type.

-- Examples:


-- Blank-padding when storing/printing char(‹n›)
SELECT t.c :: char(10)
FROM   (VALUES ('01234'),    -- padding with 5 × '␣' padding when result is printed
               ('0123456789')
       ) AS t(c);


SELECT t.c,
       length(t.c)       AS chars,
       octet_length(t.c) AS bytes
FROM   (VALUES ('x'),
               ('⚠'), -- ⚠ = U+26A0, in UTF8: 0xE2 0x9A 0xA0
               ('👩🏾')
       ) AS t(c);

-- Postgres Character Set Support Documentation

-- Example:


SELECT octet_length('012346789' :: varchar(5)) AS c1, -- 5 (truncation)
       octet_length('012'       :: varchar(5)) AS c2, -- 3 (within limits)
       octet_length('012'       :: char(5))    AS c3, -- 5 (blank padding in storage)
       length('012'             :: char(5))    AS c4, -- 3 (padding in storage only)
       length('012  '           :: char(5))    AS c5; -- 3 (trailing blanks removed)



-- Numeric Data Types:

-- numeric(<precision>, <scale>)

-- Leading zeroes are not stored in database, neither trailing zeroes for decimals are stored.

-- ¹ PostgresSQL actual limits:
--   up to 131072 digits before the decimal point,
--   up to 16383 digits after the decimal point


-- The following two queries to "benchmark" the
-- performance of numeric(.,.) vs. int arithmetics
-- (also see the resulting row width as output by EXPLAIN):

EXPLAIN ANALYZE  -- EXPLAIN ANALYZE outputs the query plan for a given query
-- 1M rows of byte width 32
WITH one_million_rows(x) AS (
  SELECT t.x :: numeric(8,0)
  FROM   generate_series(0, 1000000) AS t(x)
)
SELECT t.x + t.x AS add       -- ⎱ execution time for + (CTE Scan): ~ 2s
FROM   one_million_rows AS t; -- ⎰

-- Tupper's Formula : 

-- Since \set does not work in VS Code, the code has been updated with the actual values of k 


----------------------------------------------------------------------------------------------------
-- Video 15 : Types date/time/timestamps/interval, date/time arithmetic
----------------------------------------------------------------------------------------------------

-- Timestamps and time intervals:

-- Casting a date into timestamp sets the time to 00:00:00 for that particular date by default 
-- and timestamps also have optional time zone support represented by <t> with time zone or <t>tz .


-- Timestamps may be optionally annotated with time zones
SELECT 'now'::timestamp AS now,
       'now'::timestamp with time zone AS "now tz";

-- In PostgreSQL, timestamp resolution is 1 micro second and 1 day.

-- Special literals :

-- timestamp : epoch, infinity, now
-- date : today, tomorrow, yesterday, now 

-- User has the flexibility to set the date format and expected output format.

-- Example:


--            output  input interpretation
--             ┌─┴──┐ ┌┴┐
SET datestyle='German,MDY';
SELECT '5-4-2020' :: date;  -- May 4, 2020

SET datestyle='German,DMY';
SELECT '5-4-2020' :: date;  -- April 4, 2020

-- Back to the default datestyle
SET datestyle='ISO,MDY';



-- ISO notations have been set up to represent date time together. Given below is an example :


-- '1 year 2 months 3 days 4 hours 5 minutes 6 seconds'::interval
        
--  Can also be represented as : 

--       'P1Y2M3DT4H5M6S'::interval; -- ISO 8601
--      └──┬──┘└──┬──┘
--   date part   time part


-- Overlapping date/time intervals can be determined by the overlap function in PostgreSQL.

-- Example:


-- Do two periods of date/time overlap (infix operator 'overlaps')?

SELECT holiday.holiday
FROM   (VALUES ('Easter',    'Apr  6, 2020', 'Apr 18, 2020'),
               ('Pentecost', 'Jun  2, 2020', 'Jun 13, 2020'),
               ('Summer',    'Jul 30, 2020', 'Sep  9, 2020'),
               ('Autumn',    'Oct 26, 2020', 'Oct 31, 2020'),
               ('Winter',    'Dec 23, 2020', 'Jan  9, 2021')) AS holiday(holiday, "start", "end")
WHERE  (holiday.start :: date, holiday.end :: date) overlaps ('today','today');


-- For more extensive documentation on time zones, please refer material and data-types.sql.

-- SQL Query File : chapter03.sql

----------------------------------------------------------------------------------------------------
-- Video 16 : User-defined types: enumerations (CREATE TYPE ... AS ENUM)
----------------------------------------------------------------------------------------------------

-- Enumerations:

-- Syntax:

-- CREATE TYPE <t> AS ENUM(<v1>, <v2>,..., <vn>);
SELECT <vi>::<t>;
where vi is a case sensitive notation and stored in 4 bytes.

-- Example:

DROP TYPE IF EXISTS episode CASCADE;
CREATE TYPE episode AS ENUM
  ('ANH', 'ESB', 'TPM', 'AOTC', 'ROTS', 'ROTJ', 'TFA', 'TLJ', 'TROS');

----------------------------------------------------------------------------------------------------
-- Video 17 : Bit strings (bit(n)), BLOBS, and byte arrays (bytes)
----------------------------------------------------------------------------------------------------

-- Bit strings : 


----------------------------------------------------------------------------------------------------
-- Video 18 :
---------------------------------------------------------------------------------------------------- 

-- SQL File reference : data-types.sql

----------------------------------------------------------------------------------------------------
-- Video 19 :
----------------------------------------------------------------------------------------------------

-- SQL File reference : data-types.sql

----------------------------------------------------------------------------------------------------
-- Video 20 :
----------------------------------------------------------------------------------------------------

-- SQL File reference : data-types.sql

----------------------------------------------------------------------------------------------------
-- Video 21 : 
----------------------------------------------------------------------------------------------------

-- SQL File reference : data-types.sql

----------------------------------------------------------------------------------------------------
