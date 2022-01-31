/*NULL is larger than any NON-NULL value.

---ORDER BY : ASC by default.

---OFFSET <num> : Skips <num> rows from beginning to return the rows. <num> >=0

---LIMIT [<num>/ALL] : Fetch all rows. Available only in some databases like Postgre, mysql. In SQL server, use SELECT TOP.

---FETCH [FIRST/NEXT] <m> [ROW/ROWS] ONLY : <m> to return after the OFFSET clause has been processed. <m> >=1

---SELECT DISTINCT ON :  Goes with ORDER BY clause. Extracts 1st row among a group of equivalent rows. 
		
        
---        	prefix of ORDER BY  clause
---SELECT DISTINCT ON ➍ (‹0₁›,...,‹0ₙ›) ‹2₁›,...,‹2ₖ› -- ➋
FROM ... -- ➊
ORDER BY ‹0₁›,...,‹0ₙ›,‹0ₙ₊₁›,...,‹0ₘ› -- ➌

1. Sort rows in ‹0₁›,..., ‹0ₙ›,‹0ₙ₊₁›,...,‹0ₘ› order.
2. Rows with identical ‹0₁›,...,‹0ₙ› values form one group.
3. From each of these groups, pick the first row in
‹0ₙ₊₁›,...,‹0ₘ› order.

Example :

*/

CREATE TABLE DISTABLE(a int, b text, c text, d int);

INSERT INTO DISTABLE (a, b, c, d)
VALUES(5,'x','T',NULL),
(4,'y','F',20),
(3,'x','F',30),
(2,'y','T',40),
(1,'x','T',10);

TABLE DISTABLE;

SELECT DISTINCT ON (t.c) t.*
FROM DISTABLE AS t
ORDER BY t.c, t.d;
 
/*SELECT DISTINCT  :  Extracts only one row among a group of duplicate rows. 
No ORDER BY is required.

SELECT DISTINCT Country FROM Customers;

Difference between DISTINCT ON and DISTINCT ??

Answer : DISTINCT applies to entire tuple(all the colums)
DISTINCT ON applies to a single/specified column in your SELECT query.


AGGREGATES :  Summation/count, min/max, average, etc.
Result table will have one row.
Cannot mix aggregates with non-aggregate expressions <e> in SELECT clause; PS : GROUP BY can change the effect

*/
--ORDERED AGGREGATES: They are non-commutative(change in order will affect their result) : string_agg for example
SELECT string_agg(t.a :: text, ',' ORDER BY t.d) AS "ALL A"
FROM DISTABLE AS t;

/* FILTERED AND UNIQUE AGGREGATES: 
FILTER and DISTINCT clause

GROUP BY : While using GROUP BY clause, in SELECT clause, after the GROUPING columnm, 
we must use aggregate on next columns defined(field values) as its a bag of distinct(singular) rows returned after grouping. 
Otherwise it will violate 1NF!

Example : 
*/

--BELOW IS A VIOLATION
SELECT t.b, t.d
FROM DISTABLE AS t
GROUP BY t.b;


--BELOW IS CORRECT
SELECT t.b AS b, SUM(t.d) AS "SUMD"
FROM DISTABLE AS t
GROUP BY t.b;

/*
HAVING : operates on GROUPs/used with GROUP BY, because WHERE keyword cannot be used with aggregate functions.

SELECT column_name(s)
FROM table_name
WHERE condition
GROUP BY column_name(s)
HAVING condition
ORDER BY column_name(s);

Above query is evaluated once per group(not per row).

*/
/*
BAG OPERATIONS : 
Q1
UNION ALL
Q2

Q1
INTERSECT ALL
Q2

Q1
EXCEPT ALL
Q2

*/

--MULTI-DIMENSIONAL DATA

DROP TABLE IF EXISTS prehistoric;
CREATE TABLE prehistoric(category text, "herbivore?" boolean, legs int, species text);

INSERT INTO prehistoric (category, "herbivore?", legs, species)
VALUES
('mammalia',true,2,'Megatherium'),
('mammalia',true,4,'Paraceratherium'),
('mammalia',false,2,NULL),
('mammalia',false,4,'Sabretooth'),
('reptilia',true,2,'Iguanodon'),
('reptilia',true,4,'Brachiosaurus'),
('reptilia',false,2,'Velociraptor'),
('reptilia',false,4,NULL);

TABLE prehistoric;

-- GROUPING SETS : multiple GROUP BYs : Segregates GROUP BY in each of the columns defined under GROUPING SETS clause,
-- and then presents the result by running UNION ALL in the background on all the groups.

SELECT pH.category, 
        pH."herbivore?",
        pH.legs,
        string_agg(pH.species,', ') AS species
FROM prehistoric AS pH
GROUP BY GROUPING SETS((category),("herbivore?"),(legs));
 
-- Above query is equivalent to below :
SELECT p.category,
       NULL :: boolean             AS "herbivore?", -- ⎱  NULL is polymorphic ⇒ PostgreSQL
       NULL :: int                 AS legs,         -- ⎰  will default to type text
       string_agg(p.species, ', ') AS species
FROM   prehistoric AS p
GROUP BY p.category

  UNION ALL

SELECT NULL :: text                AS category,
       p."herbivore?",
       NULL :: int                 AS legs,
       string_agg(p.species, ',' ) AS species
FROM   prehistoric AS p
GROUP BY p."herbivore?"

  UNION ALL

SELECT NULL :: text                AS category,
       NULL :: boolean             AS "herbivore?",
       p.legs AS legs,
       string_agg(p.species, ', ') AS species
FROM   prehistoric AS p
GROUP BY p.legs;

--ROLLUP : Combines all the GROUPING SETs in a reducing format(from any node upto the root node-which is null in all the columns defined in GROUPING SETS) of the columns list defined in GROUPING SETS clause.
--combination made : cat+herb+legs, cat+herb+null, cat+null+null, null+null+null

SELECT p.category,
       p."herbivore?",
       p.legs,
       string_agg(p.species, ', ') AS species  -- string_agg ignores NULL (may use COALESCE(p.species, '?'))
FROM   prehistoric AS p
GROUP BY ROLLUP (category, "herbivore?", legs);


-- GROUPBY() : NO groupism defined then all rows form a single large group:
SELECT string_agg(p.species, ', ') AS species
FROM   prehistoric AS p
GROUP BY (); 


-- CUBE : Combines all the GROUPING SETs individually with all the possible combinations of them 
--combination made : cat+herb+legs, cat+herb+null, cat+null+null, 
--                   null+herb+legs, null+null+legs, cat+null+legs
--                   null+herb+null,  null+null+null

SELECT p.category,
       p."herbivore?",
       p.legs,
       string_agg(p.species, ', ') AS species  -- string_agg ignores NULL (may use coalesce(p.species, '?'))
FROM   prehistoric AS p
GROUP BY CUBE (class, "herbivore?", legs);


/*SQL Evaluation Order vs Reading Order

Reading Order is straightforward : as the statement is written, sequential reading

Evaluation : 

1. FROM
2. WHERE
3. SELECT <GROUP BY COLUMN : gbc >(num 3 is SELECT only if GROUP BY clause is written)
4. GROUP BY <gbc>
5. HAVING
6. any AGGREGATEs column defined in SELECT query
7. DISTINCT ON clause in SELECT query(if defined)
8. UNION/INTERSECT/EXCEPT(Joining of statements)
9. ORDER BY
10. OFFSET/LIMIT


WITH CTEs
Advantage over SUB-QUERIES :
makes code more readable, 
can call recursively, 
can reuse again,
can create a temp table on the go and use it for quering anything without a table creation: see query prehistoric1 below. 
For more info : https://learnsql.com/blog/sql-subquery-cte-difference/

*/

DROP TABLE IF EXISTS prehistoric1

WITH prehistoric1(category, "herbivore?", legs, species) AS(
    VALUES('mammalia',true,2,'Megatherium'),
('mammalia',true,4,'Paraceratherium'),
('mammalia',false,2,NULL),
('mammalia',false,4,'Sabretooth'),
('reptilia',true,2,'Iguanodon'),
('reptilia',true,4,'Brachiosaurus'),
('reptilia',false,2,'Velociraptor'),
('reptilia',false,4,NULL)
)
SELECT MAX(p.legs)
FROM prehistoric1 AS p;

TABLE prehistoric1;


--Use case of WITH CTE below

DROP TABLE IF EXISTS dinosaurs;
CREATE TABLE dinosaurs (species text, height float, length float, legs int);

INSERT INTO dinosaurs(species, height, length, legs) VALUES
  ('Ceratosaurus',      4.0,   6.1,  2),
  ('Deinonychus',       1.5,   2.7,  2),
  ('Microvenator',      0.8,   1.2,  2),
  ('Plateosaurus',      2.1,   7.9,  2),
  ('Spinosaurus',       2.4,  12.2,  2),
  ('Tyrannosaurus',     7.0,  15.2,  2),
  ('Velociraptor',      0.6,   1.8,  2),
  ('Apatosaurus',       2.2,  22.9,  4),
  ('Brachiosaurus',     7.6,  30.5,  4),
  ('Diplodocus',        3.6,  27.1,  4),
  ('Supersaurus',      10.0,  30.5,  4),
  ('Albertosaurus',     4.6,   9.1,  NULL),  -- Bi-/quadropedality is
  ('Argentinosaurus',  10.7,  36.6,  NULL),  -- unknown for these species.
  ('Compsognathus',     0.6,   0.9,  NULL),  --
  ('Gallimimus',        2.4,   5.5,  NULL),  -- Try to infer pedality from
  ('Mamenchisaurus',    5.3,  21.0,  NULL),  -- their ratio of body height
  ('Oviraptor',         0.9,   1.5,  NULL),  -- to length.
  ('Ultrasaurus',       8.1,  30.5,  NULL);  --

TABLE dinosaurs;

-- Determine characteristic height/length (= body shape) ratio
-- separately for bipedal and quadropedal dinosaurs:
WITH bodies(legs, shape) AS (
  SELECT d.legs, AVG(d.height / d.length) AS shape
  FROM   dinosaurs AS d
  WHERE  d.legs IS NOT NULL
  GROUP BY d.legs
)
SELECT d.species, d.height, d.length,
       (SELECT b.legs                               -- Find the shape entry in bodies
        FROM   bodies AS b                          -- that matches d's ratio of
        ORDER BY abs(b.shape - d.height / d.length) -- height to length the closest
        LIMIT 1) AS legs                            -- (pick row with minimal shape difference)
FROM  dinosaurs AS d
WHERE d.legs IS NULL
                      -- ↑ Locomotion of dinosaur d is unknown
  UNION ALL           ----------------------------------------
                      -- ↓ Locomotion of dinosaur d is known
SELECT d.*
FROM   dinosaurs AS d
WHERE  d.legs IS NOT NULL;

 