
-- Key Concepts Covered :  Built-in data types, casting, string data type, numeric data type, 
-- date / time / timestamps, intervals, user defined data types, bit strings, blobs, bit arrays,
-- range / interval types and operations, geometric objects and operations and their use cases,
-- JSON support, sequences and key generation

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

-- Tupper's self-referential formula
--
-- Plot points x ∊ [0,106), y ∊ [k, k+17) for which
-- ½ < ⌊mod(⌊y/17⌋ × 2^(-17 × ⌊x⌋ - mod(⌊y⌋, 17), 2)⌋
-- holds.
--
-- The plotted image contains a representation of the formula itself:
--
--          █                   █                █ ██ █     █                █  █ █     █    █ ██ █      █   █
--          █                   █ █      █       █  █ █     █                █  █ █     █    █  █ █      █   █
--  ██      █                  █  █      █    ██ █  █ █ █ █ █ ██ ████  ███ ███ █  █ █ █ █    █  █  █      █  █
--   █      █                  █  █  █ █ █       █ █  █  █  █    █ █ █ █ █ █ █ █  █ █ █ █    █ █   █      █  █
--   █      █                  █  █  █ █ █       █ █  █ █ █ █    █ █ █ ███ ███ █  █  █  █    █ █   █      █  █
--   █      █               █ █   █   █  █  ██        █     █                  █  █ █   █  █       █   ██  █ █
--  ███   █ █               █ █   █  █   █ █  █       █     █                   █ █     █  █      █   █  █ █ █
--       █  █ ██ █   ██   ███ █   █      █   █        ███ ███                   █ ███ ███ █       █     █  █ █
--  ███ █   █ █ █ █ █  █ █  █ █   █ ████ █  █                                                          █   █ █
--       █  █ █ █ █ █  █ █  █ █   █      █ █                                                          █    █ █
--  ██    █ █ █ █ █  ██   ███ █   █ █ ██ █ ████                                                       ████ █ █
--    █     █                 █   █ █  █ █                                                          █      █ █
--   █      █                  █  █ █  █ █                                                          █     █  █
--  █       █                  █  █ █ █  █                                                         █      █  █
--  ███     █                  █  █ █ █  █                                                                █  █
--          █                   █ █      █                                                               █   █
--          ███                 █ ███  ███                                                               █ ███
--
--
-- Can encode *any* 106x17 pixel image in terms of a single value of type numeric
-- (see pixel image editor at http://tuppers-formula.tk): the following encodes the
-- text "Advanced SQL":
--
-- \set k 52286934557658048028425956698007592392599530361873363333609880711749360515697214536719655759234958981559142573143695142261512175715575262178445160479745224050413186652132299326608682173356922986884858803658784114284120559745186144099152093031123509671116955442905501004550625844483047202158923745405732677551008895706387756563881115671352441965257523184483317832915333353792671679709434918092340808285147480120213896185154950991291329376438314822230636406240307557327442470102492396220365764965812928512

-- \set k 960939379918958884971672962127852754715004339660129306651505519271702802395266424689642842174350718121267153782770623355993237280874144307891325963941337723487857735749823926629715517173716995165232890538221612403238855866184013235585136048828693337902491454229288667081096184496091705183454067827731551705405381627380967602565625016981482083418783163849115590225610003652351370343874461848378737238198224849863465033159410054974700593138339226497249461751545728366702369745461014655997933798537483143786841806593422227898388722980000748404719

WITH
tupper(x, y, pixel) AS (
  SELECT x, y - 960939379918958884971672962127852754715004339660129306651505519271702802395266424689642842174350718121267153782770623355993237280874144307891325963941337723487857735749823926629715517173716995165232890538221612403238855866184013235585136048828693337902491454229288667081096184496091705183454067827731551705405381627380967602565625016981482083418783163849115590225610003652351370343874461848378737238198224849863465033159410054974700593138339226497249461751545728366702369745461014655997933798537483143786841806593422227898388722980000748404719 AS y,
         --   ½ < ⌊mod(⌊y/17⌋ × 2^(-17 × ⌊x⌋ - mod(⌊y⌋, 17), 2)⌋  (NB: replaced ⋯ × 2⁻ˣ by ⋯ / 2ˣ)
         0.5 < floor(mod(floor(y / 17.0) / 2^(-(-17 * floor(x) - mod(floor(y), 17))) :: numeric, 2)) AS pixel
  FROM   generate_series(0 , 105)   AS x,  -- x ∊ [0,106)
         generate_series(960939379918958884971672962127852754715004339660129306651505519271702802395266424689642842174350718121267153782770623355993237280874144307891325963941337723487857735749823926629715517173716995165232890538221612403238855866184013235585136048828693337902491454229288667081096184496091705183454067827731551705405381627380967602565625016981482083418783163849115590225610003652351370343874461848378737238198224849863465033159410054974700593138339226497249461751545728366702369745461014655997933798537483143786841806593422227898388722980000748404719, 960939379918958884971672962127852754715004339660129306651505519271702802395266424689642842174350718121267153782770623355993237280874144307891325963941337723487857735749823926629715517173716995165232890538221612403238855866184013235585136048828693337902491454229288667081096184496091705183454067827731551705405381627380967602565625016981482083418783163849115590225610003652351370343874461848378737238198224849863465033159410054974700593138339226497249461751545728366702369745461014655997933798537483143786841806593422227898388722980000748404719+16) AS y   -- y ∊ [k,k+17)
)
-- Plot pixels
SELECT string_agg(CASE WHEN t.pixel THEN '█' ELSE ' ' END, NULL ORDER BY t.x DESC) AS "Tupper's Formula"
FROM   tupper AS t
GROUP BY t.y
ORDER BY t.y;

----------------------------------------------------------------------------------------------------
-- Types date/time/timestamps/interval, date/time arithmetic
----------------------------------------------------------------------------------------------------

-- Timestamps and time intervals:

-- Casting a date into timestamp sets the time to 00:00:00 for that particular date by default 
-- and timestamps also have optional time zone support represented by <t> with time zone or <t>tz .

-- Timestamps/Intervals

SELECT 'now'::date      AS "now (date)",
       'now'::time      AS "now (time)",
       'now'::timestamp AS "now (timestamp)";

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

-- Examples :

-- Dates may be specified in a variety of forms
SELECT COUNT(DISTINCT birthdays.d::date) AS interpretations
FROM   (VALUES ('August 26, 1968'),
               ('Aug 26, 1968'),
               ('8.26.1968'),
               ('08-26-1968'),
               ('8/26/1968')) AS birthdays(d);

-- Special timestamps and dates
SELECT 'epoch'::timestamp    AS epoch,
       'infinity'::timestamp AS infinity,
       'today'::date         AS today,
       'yesterday'::date     AS yesterday,
       'tomorrow'::date      AS tomorrow;


-- ISO notations have been set up to represent date time together. Given below is an example :


-- '1 year 2 months 3 days 4 hours 5 minutes 6 seconds'::interval
        
--  Can also be represented as : 

--       'P1Y2M3DT4H5M6S'::interval; -- ISO 8601
--      └──┬──┘└──┬──┘
--   date part   time part

-- Examples :

-- Date/time arithmetics with intervals

SELECT 'Aug 31, 2035'::date - 'now'::timestamp                     AS retirement,
       'now'::date + '30 days'::interval                           AS in_one_month,
       'now'::date + 2 * '1 month'::interval                       AS in_two_months,
       'tomorrow'::date - 'now'::timestamp                         AS til_midnight,
        extract(hours from ('tomorrow'::date - 'now'::timestamp))  AS hours_til_midnight,
       'tomorrow'::date - 'yesterday'::date                        AS two, -- ⚠ yields int
       make_interval(days => 'tomorrow'::date - 'yesterday'::date) AS two_days;

-- Printing the last day of every month

--                year    month  day
--                 ↓        ↓     ↓
SELECT (make_date(2020, months.m, 1) - '1 day'::interval)::date AS last_day_of_month
FROM   generate_series(1,12) AS months(m);

-- Show the time zome difference between current time zone and different time zones

SELECT timezones.tz AS timezone,
       'now'::timestamp with time zone -- uses default ("show time zone")
         -
       ('now'::timestamp::text || ' ' || timezones.tz)::timestamp with time zone AS difference
FROM   (VALUES ('America/New_York'),
               ('Europe/Berlin'),
               ('Asia/Tokyo'),
               ('PST'),
               ('UTC'),
               ('UTC-6'),
               ('+3')
       ) AS timezones(tz)
ORDER BY difference;


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

----------------------------------------------------------------------------------------------------
-- User-defined types: enumerations (CREATE TYPE ... AS ENUM)
----------------------------------------------------------------------------------------------------

-- Enumerations:

-- Syntax:

-- CREATE TYPE <t> AS ENUM(<v1>, <v2>,..., <vn>);
-- SELECT <vi>::<t>;
-- where vi is a case sensitive notation and stored in 4 bytes.

-- Example:

DROP TYPE IF EXISTS episode CASCADE;
CREATE TYPE episode AS ENUM
  ('ANH', 'ESB', 'TPM', 'AOTC', 'ROTS', 'ROTJ', 'TFA', 'TLJ', 'TROS');

DROP TABLE IF EXISTS starwars;
CREATE TABLE starwars(film    episode PRIMARY KEY,
                      title   text,
                      release date);

INSERT INTO starwars(film,title,release) VALUES
    ('TPM',  'The Phantom Menace',      'May 19, 1999'),
    ('AOTC', 'Attack of the Clones',    'May 16, 2002'),
    ('ROTS', 'Revenge of the Sith',     'May 19, 2005'),
    ('ANH',  'A New Hope',              'May 25, 1977'),
    ('ESB',  'The Empire Strikes Back', 'May 21, 1980'),
    ('ROTJ', 'Return of the Jedi',      'May 25, 1983'),
    ('TFA',  'The Force Awakens',       'Dec 18, 2015'),
    ('TLJ',  'The Last Jedi',           'Dec 15, 2017'),
    ('TROS', 'The Rise of Skywalker',   'Dec 19, 2019');
--     ↑              ↑                        ↑
-- ::episode       ::text                    ::date

INSERT INTO starwars(film,title,release) VALUES
  ('R1', 'Rogue One', 'Dec 15, 2016');
--   ↑
-- ⚠ not an episode value - throws error

-- Order of enumerated type yields the Star Wars Machete order
SELECT s.*
FROM   starwars AS s
ORDER BY s.film; -- s.release; -- yields chronological order

----------------------------------------------------------------------------------------------------
-- Bit strings (bit(n)), BLOBS, and byte arrays (bytes)
----------------------------------------------------------------------------------------------------

-- Bit strings : 

-- Data type bit stores strings of n binary digits(storage: 1 byte per 8 bits + constant small overhead)

-- Literals :

-- SELECT B'00101010', X'2A', '00101010'::bit(8), 42::bit(8)

-- Bitwise operations: & (and), | (or), # (xor), ~ (not),
-- <</>> (shift left/right), get_bit(･,･), set_bit(･,･)

-- String-like operations: || (concatenation), length(･),
-- bit_length(･), octet_length(･), position(･ in ･), …

-- Binary Arrays (BLOBs) :

-- Store binary large object blocks(BLOBs) in the column of type bytea in form of in-line
-- alphanumeric data.
-- BLOBs remain uninterpreted by DBMS.   

-- BLOBs are stored alongside indentifying key data and additional properties i.e. the file metadata
-- is made explicit to filter/group/order BLOBs.   

-- Encoding/Decoding BLOBs :

-- The binary data present in the file system has to be converted into a bytea column of the table to
-- store data inside POSTGRESQL. 

-- We can either use a UDF or standard POSTGRESQL functions like lo_import()

-- The other way is to encode the binary data into a base64 text string and then decode it again
-- into a bytea column (decode is function available in Postgres)

-- The file I/O is performed by the DBMS server

-- Example:

-- Store and play GLaDOS voice lines from Portal 1 & 2

DROP TYPE IF EXISTS edition CASCADE;

CREATE TYPE edition AS ENUM ('Portal 1', 'Portal 2');

DROP TABLE IF EXISTS glados;

CREATE TABLE glados (id     int PRIMARY KEY, -- key
                     voice  bytea,           -- BLOB data
                     line   text,            -- ⎱ meta data,
                     portal edition);        -- ⎰ properties

-- User-defined Python procedure: read BLOB from file

-- In case the extensions, don't work, you might need to check for python version
-- as well as set the correct path and environment variables.

CREATE EXTENSION IF NOT EXISTS plpython3u;

DROP FUNCTION IF EXISTS read_blob(text) CASCADE;
CREATE FUNCTION read_blob(blob text) RETURNS bytea AS
$$
  try:
    file = open(blob)
    return file.read()
  except:
    pass
  #could not read file, return NULL
  return None
$$ LANGUAGE plpython3u;

-- Insert values into the table 

INSERT INTO glados(id, line, portal, voice)
  SELECT quotes.id, quotes.line, quotes.portal :: edition,
         read_blob('.\GLaDOS' || quotes.wav) AS voice
  FROM
    (VALUES (1, '... you will be missed',       'Portal 1', 'will-be-missed.wav'),
            (2, 'Two plus two is...ten',        'Portal 1', 'base-four.wav'),
            (3, 'The facility is ...',          'Portal 2', 'facility-operational.wav'),
            (4, 'Don''t press that button ...', 'Portal 2', 'press-button.wav')) AS quotes(id,line,portal,wav);

-- Dump table contents, encode (prefix of) BLOB for table output
SELECT g.id, g.line, g.portal,
       left(encode(g.voice, 'base64'), 20) AS voice -- output 20 characters of output
FROM   glados AS g;

-- Extract selected GLaDOS voice line, play the resulting audio file
-- (on macOS/SoX) via
--
--   $ play -q /tmp/GlaDOS-says.wav
--
COPY (
  SELECT translate(encode(g.voice, 'base64'), E'\n', '')
  FROM   glados AS g
  WHERE  g.id = 3
) TO PROGRAM 'base64 -D > \tmp\GlaDOS-says.wav';

----------------------------------------------------------------------------------------------------
-- Range/interval types and operations
---------------------------------------------------------------------------------------------------- 

-- Ranges (Intervals):

-- Range literals can be of type int4, int8, num(eric), timestamp, date

SELECT '(1, 10]'::int4range;

-- OUTPUT : [2, 11)

-- Let r1, r2 and r3 be three ranges
-- Let p be any point in this range

-- r₁ ⁅──────────[
-- r₂            ⁅─────[
-- r₃   ⁅─────[        ┊
-- p  ･ ┊     ┊       ┊
-- ----------------------> τ
--      ┊     ┊       ┊         r₁ @> p r₃ <@ r₁ contains, contained by
--      ┊     ┊       ┊         r₁ -|- r₂ is adjacent to
--      ┊     ┊       ┊         r₃ << r₂ r₁ << r₂ strictly left of
--      ⁅─────┊───────[         r₂ + r₃ union
--      ⁅─────[                 r₁ ＊ r₃ intersection
--                              r₁ && r₃ overlaps

-- There are also some additional range supporting functions:

-- lower(･), upper(･) (bound extraction)
-- lower_inc(･) (bound closed?), lower_inf(･) (unbounded?)
-- isempty(･)

-- Check for the intersection of two intervals
SELECT int4range(1, 5, '[]') * '[5, 10)'::int4range;

-- OUTPUT : [5,6)

----------------------------------------------------------------------------------------------------
-- Geometric objects and operations, use case: shape scanner
----------------------------------------------------------------------------------------------------

-- Geometric Objects :   

-- To construct geometric objects in Postgres, we have predefined syntaxes:   

-- '(A,B)'        - Construct a point
-- point(A,B)     - Construct a point
-- line(p₁,p₂)    - Construct a line
-- lseg(p₁,p₂)    - Construct a line segment
-- box(p₁,p₂)     - Construct a box
-- '[p₁,…,pₙ]'     - Construct an open path
-- '(p₁,…,pₙ)'     - Construct a polygon
-- circle(p,r)    - Construct a circle

-- Alternative string literal syntax (see PostgreSQL docs):
-- '((P₁,R₁),(P₂,R₂))'::lseg, '<(P,R),9>'::circle, ...

-- Querying Geometric Objects : 

-- SYNTAX             OPERATION

-- +, -               translate 
-- area(･)            area
-- *                  scale/rotate
-- height(･)          height of box
-- @-@                length/circumference 
-- width(･)           width of box
-- @@                 center 
-- bound_box(･,･)     bounding box
-- <->                distance between 
-- diameter(･)        diameter of circle
-- &&                 overlaps? 
--  center(･)         center
-- <<                 strictly left of? 
-- isclosed(･)        path closed?
-- ?-│                is perpendicular? 
-- npoints(･)         # of points in path
-- @>                 contains? 
-- pclose(･)          close an open path

-- ‹p›[0], ‹p›[1] to access x/y coordinate of point p.

-- Example:

-- Estimate the value of π using the "Monte Carlo method":
--
-- ➊ Place circle c with r = 0.5 at point (0.5, 0.5).
--   Area of c is πr² = π/4.
-- ➋ Generate random point p in unit square (0,0)-(1,1).
--   Area of square is 1.
-- ⇒ Chance of p being in c = (π/4)/1 = π/4.
--
--               π/4 = nᵢₙ/n


-- # of random points to generate
-- \set N 100000

SELECT (COUNT(*)::float / 100000) * 4 AS π
FROM   generate_series(1, 100000) AS _
WHERE  circle(point(0.5,0.5), 0.5) @> point(random(),random());
--                                 ↑
--                       circle contains point?

-- USE CASE : SHAPE SCANNER

-- Given an unknown shape (a polygon geometric object):
-- 1. Perform horizontal “scan” to trace minimum/maximum(i.e., bottom/top) R values for each P.
-- 2. Use bottom/top traces to render the shape.

-- SQL Query:      

-- Perform a horizontal "scan" of a shape to trace its top and
-- bottom edges.
--
--
-- Demonstrates:
-- - WITH (non-recursive CTEs)
-- - generate_series()
-- - geometric objects and operations


-- Scan RESOLUTION in x/y dimension
-- \set RESOLUTION 0.01
-- Shape id to scan
-- \set SHAPE 3

  WITH
  -- A table of shapes (polygons)
  shapes(id, shape) AS (
    VALUES (1, '((0,0), (1,1.5), (2,0))'::polygon),              -- △
           (2, polygon(box(point(0.5,0.5) , point(1.2, 3.0)))),  -- □
           (3, polygon(circle(point(0,0), 1))),                  -- ○ (12 points)
           (4, '((0,1), (2,2), (0,3), (2,4),
                 (3,2), (5,1), (3,0))'::polygon)                 -- ⭔ (complex)
  ),
  -- Determine center, width, and height of box around shape s
  -- ⚠ The repeated computation of box(s.shape) calls for use of LATERAL
  --    (see replacement query for bboxes below)
  boxes(id, center, w, h) AS (
    SELECT s.id,
           center(box(s.shape))  AS center,
           width(box(s.shape))   AS width,
           height(box(s.shape))  AS height
    FROM   shapes AS s
  ),
  -- Perform horizontal scan of all shapes:
  -- 1. The bounding boxes provide scan ranges in x/y dimensions
  -- 2. Test whether point (x,y) lies in shape
  -- 3. Record minimum (bottom) and maximum (top) y value for each x
  trace(id, x, bottom, top) AS (
    SELECT  s.id, x, MIN(y) AS bottom, MAX(y) AS top
    FROM    shapes AS s, boxes AS b,
            generate_series((b.center[0] - b.w / 2) :: numeric, (b.center[0] + b.w / 2) :: numeric, 0.01) AS x,
            generate_series((b.center[1] - b.h / 2) :: numeric, (b.center[1] + b.h / 2) :: numeric, 0.01) AS y
    WHERE   s.id = b.id
    AND     point(x,y) <@ s.shape
    GROUP BY s.id, x
    ORDER BY s.id, x
  )
  SELECT t.x, t.bottom, t.top
  FROM   trace AS t
  WHERE  t.id = 3

-- The given set of points can be copied into a CSV file and plotted using gnuplot or matplotlib
-- for a visual representation.

----------------------------------------------------------------------------------------------------
-- JSON support (type jsonb) [and XML support]
----------------------------------------------------------------------------------------------------

-- 

----------------------------------------------------------------------------------------------------
--  
----------------------------------------------------------------------------------------------------

-- 

----------------------------------------------------------------------------------------------------
