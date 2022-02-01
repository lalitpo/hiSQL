--Array {x1,x2,,,,,,xn} in SQL can only have homogenous elements, user defined types(enums, row types)
--Array size  is unspecified/dynamic.
--Array indexes are of type int and 1-based.
--Empty 1D array have to be typecasted to a certain type because it can be of any type.
--Multi-dimensional array should have all sub-arrays of same size/length.
--Multi-dimensional array have rectangular structure as below :
--     1 .......
--     . .......
--     . .......
--     k .......
--       1.....n


-- Example : Tree Encoding(parents[i]== parent of node i)

-- Represent labelled forests using arrays:
-- - if parents[i] = j, then j is parent node of node i,
-- - if labels[i] = ℓ, then ℓ is the label of node i.

DROP TABLE IF EXISTS Trees;

CREATE TABLE Trees (tree    int PRIMARY KEY,
                    parents int[],
                    labels  text[]);

--      t₁                  t₂                     t₃
--
--   ¹     ᵃ           ⁶     ᵍ           ¹   ³     ᵃ    ╷ᵈ
-- ² ⁵  ᵇ ᶜ        ⁴ ⁷  ᵇ ᶜ                       ╵
--      ╵        ¹ ⁵  ᵈ ᵉ          ² ⁴   ⁵     ᵇ ᶜ    ᵉ
-- ³ ⁴⁶   ᵈ ᵉᶠ              
--                    ² ³    ᶠ ᵃ

INSERT INTO Trees(tree, parents, labels) VALUES
  (1, array[NULL,1,2,2,1,5],   array['a','b','d','e','c','f']),
  (2, array[4,1,1,6,4,NULL,6], array['d','f','a','b','e','g','c']),
  (3, array[NULL,1,NULL,1,3],  string_to_array('a;b;d;c;e',';'));

TABLE trees;


-- CONSTRUCTING ARRAYS :
-- Append elements : array_append(array[x1,....,xn], new_elem)  OR   arr1 || new_ele
-- Prepend elements : array_prepend(array[x1,....,xn], new_elem)  OR   new_ele || arr1
-- Concatenation : array_cat(arr1, arr2)  OR   arr1 || arr2

-- Accessing Arrays : 
-- arr[i] = x
-- (NULL)[i] = NULL
-- arr[NULL] = NULL
-- arr[i:j] = arr[xi,....,xj]
-- arr[i:] = arr[xi,....,xn]
-- arr[:j] = arr[x1,....,xj]

-- Access last element xn : 
-- arr[array_length(arr,1)] : 1 is the dimension of the array 
-- arr[cardinality(arr)] : Cardinality function gives length. 
-- For multi-dimensional, gives the total number of elements : n(length)*k(num of rectangular arrays) 

-- array_position(arr, ele) : i . If not found, returns NULL
-- array_positions(arr, ele) : returns all occurences of the element. If not found, returns empty array.

-- array_replace(arr, old_ele, new_ele) : returns the new array.

-- comparison operator θ ∈ {=,<,>,<>,<=,>=}:
-- x θ ANY(arr]) ≡ ∃ ^i{1,⋯,n}: x θ arr[i]
-- x θ ALL(arr]) ≡ ∀ ^i{1,⋯,n}: x θ arr[i]


-- Consistency: length of parents[] and labels[] match for all trees?
--
SELECT bool_and(cardinality(t.parents) = cardinality(t.labels))
FROM   Trees AS t;

-- Which trees (and nodes) carry an 'f' label?
--
SELECT t.tree, array_positions(t.labels, 'f') AS "f nodes"
FROM   Trees AS t
WHERE  'f' = ANY(t.labels);


-- Find the label of the (first) root
--
SELECT t.tree, t.labels[array_position(t.parents,NULL)] AS root
FROM   Trees AS t;


-- Which trees actually are forests (collection of trees with more
-- than one root)?
--
SELECT t.tree AS forest
FROM   Trees AS t
WHERE  cardinality(array_positions(t.parents,NULL)) > 1;


-----------------------------------------------------------------------
-- unnest / array_agg

-- array_agg(tablename.columnname) : transforms a column values into an array
-- unnest(arr) : transforms into a table of a single column. Order of elements is lost. To fix this, use ORDINALITY

SELECT t.*
FROM   unnest(array['x₁','x₂','x₃']) AS t(elem);

SELECT t.*
FROM   unnest(array['x₁','x₂','x₃']) WITH ORDINALITY AS t(elem,idx);

--                                   try: DESC
--                                      ↓
SELECT array_agg(t.elem ORDER BY t.idx ASC) AS xs
FROM   (VALUES ('x₁',1),
               ('x₂',2),
               ('x₃',3)) AS t(elem,idx);



-- unnest() indeed is a n-ary function that unnest multiple
-- arrays at once: unnest(xs₁,...,xsₙ), one per column.  Shorter
-- columns are padded with NULL (see zipping in table-functions.sql):
--
SELECT node.parent, node.label
FROM   Trees AS t,
       unnest(t.parents, t.labels) AS node(parent,label)
WHERE  t.tree = 2;


SELECT node.*
FROM   Trees AS t,
       unnest(t.parents, t.labels) WITH ORDINALITY AS node(parent,label,idx)
WHERE  t.tree = 2;


-- Transform all labels to uppercase:
--
SELECT t.tree,
       array_agg(node.parent ORDER BY node.idx) AS parents,
       array_agg(upper(node.label) ORDER BY node.idx) AS labels
FROM   Trees AS t,
       unnest(t.parents,t.labels) WITH ORDINALITY AS node(parent,label,idx)
GROUP BY t.tree;


-- Find the parents of all nodes with label 'c'
--
SELECT t.tree, t.parents[node.idx] AS "parent of c"
FROM   Trees AS t,
       unnest(t.labels) WITH ORDINALITY AS node(label,idx)
WHERE  node.label = 'c';


-- Find the forests among the trees:
--
SELECT t.*
FROM   Trees AS t,
       unnest(t.parents) AS node(parent)
WHERE  node.parent IS NULL
GROUP BY t.tree
HAVING COUNT(*) > 1; -- true forests have more than one root node


-- Problem ➋ (attach tree t₂ to leaf 6/f of t₁).  Yes, this is getting
-- ugly and awkward.  Arrays are helpful, but SQL is not an array
-- programming language.
--
-- Plan: append nodes of t₁ to those of t₂:
--
-- 1. Determine root r and size s (= node count) of t₂
-- 2. Shift all parents of t₁ by s, preserve labels
-- 3. Concatenate the parents of t₂ and t₁, set the parent of t2's root to leaf ℓ (shifted by s),
--    concatenate the labels of t₂ and t₁

\set t1 1
\set ℓ 6
\set t2 2

WITH
-- 1. Determine root r and size s (= node count) of t2
t2(root,size,parents,labels) AS (
  SELECT array_position(t2.parents,NULL) AS root,
         cardinality(t2.parents) AS size,
         t2.parents,
         t2.labels
  FROM   Trees AS t2
  WHERE  t2.tree = :t2
),
-- 2. Shift all parents of t1 by s, preserve labels
t1(parents,labels) AS (
  SELECT (SELECT array_agg(node.parent + t2.size ORDER BY node.idx)
          FROM   unnest(t1.parents) WITH ORDINALITY AS node(parent,idx)) AS parents,
         t1.labels
  FROM   Trees AS t1, t2
  WHERE  t1.tree = :t1
)
-- 3. Concatenate the parents of t2 and t1, set the parent of t2's root to leaf ℓ (shifted by s),
--    concatenate the labels of t2 and t1
SELECT (SELECT array_agg(CASE node.idx WHEN t2.root THEN :ℓ + t2.size
                                       ELSE node.parent
                         END
                         ORDER BY node.idx)
        FROM   unnest(t2.parents) WITH ORDINALITY AS node(parent,idx)) || t1.parents AS parents,
       t2.labels || t1.labels AS labels
FROM   t1, t2;


--SERIES AND SUBSCRIPT GENERATORS

-- generate_series(start, end, step) : generate a column having row values starting from 'start' till end(=< end) with increase of 'step'
-- generate_subscript(arr, dimension) : generates a series of intergers representing the subscripts of the specified array.

SELECT generate_subscripts(ARRAY['foo','bar','baz'], 1);

--Subscripts can be returned in reverse order:

SELECT generate_subscripts(ARRAY['foo','bar','baz'], 1, TRUE);

--Generating subscripts for a multi-dimensional array:

SELECT generate_subscripts(ARRAY[​['foo','bar','baz'],['boo','bom','bop']​], 1);

--No values are returned if an invalid array dimension is specified:

SELECT generate_subscripts(ARRAY['foo','bar','baz'], 2);

--TEXT GENERATORS
 
--regexp_matches(‹t›,‹reg›,'g') : returns a text array of all of the captured substrings resulting from matching a POSIX regular expression pattern
--  t is input string to check, <reg> is regular expression to check with, 'g' is a flag indicating to return each match in the string, not only the first one, and return a row for each such match. 

SELECT regexp_matches('foobarbequebaz', '(bar)(beque)');

SELECT regexp_matches('foobarbequebazilbarfbonk', '(b[^b]+)(b[^b]+)', 'g');

SELECT regexp_matches('foobarbequebaz', 'barbeque');

-- Breaking Bad: Parse a chemical formula
--
-- (C₆H₅O₇³⁻ is Citrate)

-- Variant on slide: report NULL (≡ no charge) if charge unspecified
SELECT t.match[1] AS element, t.match[2] AS "# atoms", t.match[3] AS charge
FROM   regexp_matches('C₆H₅O₇³⁻',
                      '([A-Za-z]+)([₀₁₂₃₄₅₆₇₈₉]*)([⁰¹²³⁴⁵⁶⁷⁸⁹]+[⁺⁻])?',
                      'g')                    -- ────────────────
       AS t(match);                           -- does not match if no charge ⇒ yields NULL


SELECT t.match[1] AS element, t.match[2] AS "# atoms", t.match[3] AS charge
FROM   regexp_matches('C₆H₅O₇³⁻',                                            -- input text ‹t›
                      '([A-Za-z]+)([₀₁₂₃₄₅₆₇₈₉]*)((?:[⁰¹²³⁴⁵⁶⁷⁸⁹]+[⁺⁻])?)',  -- regular expression ‹re›
                      'g')                    -- ─────────────────────
       AS t(match);                           -- matches empty string if no charge ⇒ yields ''


--regexp_split_to_table(‹t›,‹reg›) : splits a string using regular expression pattern as a delimiter. Returns in table form.

SELECT foo FROM regexp_split_to_table('the quick brown fox jumps over the lazy dog', '\s+') AS foo;

-- Split string into whitespace-separated words
--
SELECT t.word
FROM   regexp_split_to_table('Luke, I am Your Father', '\s+') AS t(word);
--                                                       ↑
--                       any white space character, alternatively: [[:space:]]

--regexp_split_to_array(‹t›,‹reg›) : splits a string using regular expression pattern as a delimiter. Returns in array form.

SELECT regexp_split_to_array('the quick brown fox jumps over the lazy dog', '\s+');



--USER DEFINED FUNCTIONS:

-- CREATE FUNCTION fname(arg1, arg2, ...., argn) RETURNS <abc> A
--  $$
--<QUERY1>
--<QUERY1>
--.
--.
--.
--<QUERYN>
-- $$
-- LANGUGAGE SQL [IMMUTABLE] : means no write data being done, only for select queries, no side effect on database records, no DML queries.
-- Can use VOLATILE if not IMMUTABLE
--Overloading of functions is possible only if the function name and type of argument list is unique.
--Limited polymorphism : any argument and return type may be anyelement/anyarray/anyenum/anyrange and more than once of such occurence indicates the same function.
-- f1(a,a) -> returns boolean
-- f1(a,b) -> returns boolean ... this is not possible: limited polymorphism


-- Atomic return type (int)
-- Map subscript symbols to their numeric value: '₀' to 0, '₁' to 1, ...
-- (returns NULL if a non-subscript symbol is passed)
--
DROP FUNCTION IF EXISTS subscript(text);
CREATE FUNCTION subscript(s text) RETURNS int AS
$$
  SELECT subs.value
  FROM   (VALUES ('₀', 0),
                 ('₁', 1),
                 ('₂', 2),
                 ('₃', 3),
                 ('₄', 4),
                 ('₅', 5),
                 ('₆', 6),
                 ('₇', 7),
                 ('₈', 8),
                 ('₉', 9)) AS subs(sym,value)
  WHERE  subs.sym = s
$$
LANGUAGE SQL IMMUTABLE;


-- Alternative variant using array/WITH ORDINALITY
--
DROP FUNCTION IF EXISTS subscript(text);
CREATE FUNCTION subscript(s text) RETURNS int AS
$$
  SELECT subs.value::int - 1
  FROM   unnest(array['₀','₁','₂','₃','₄','₅','₆','₇','₈','₉'])
         WITH ORDINALITY AS subs(sym,value)
  WHERE  subs.sym = s
$$
LANGUAGE SQL IMMUTABLE;


-- Modify chemical formula parser (see above): returns actual atom count
--
--                                 ↓
SELECT t.match[1] AS element, subscript(t.match[2]) AS "# atoms", t.match[3] AS charge
FROM   regexp_matches('C₆H₅O₇³⁻',
                      '([A-Za-z]+)([₀₁₂₃₄₅₆₇₈₉]*)([⁰¹²³⁴⁵⁶⁷⁸⁹]+[⁺⁻])?',
                      'g')                    -- ────────────────
       AS t(match);                           -- does not match if no charge ⇒ yields NULL



-- Atomic return type (text), incurs side effect
-- Generate a unique ID of the form '‹prefix›###' and log time of generation
--
DROP TABLE IF EXISTS issue;
CREATE TABLE issue (
  id     int GENERATED ALWAYS AS IDENTITY,
  "when" timestamp);

DROP FUNCTION IF EXISTS new_ID(text);
CREATE FUNCTION new_ID(prefix text) RETURNS text AS
$$
  INSERT INTO issue(id, "when") VALUES
    (DEFAULT, 'now'::timestamp)
  RETURNING prefix || id::text
$$
LANGUAGE SQL VOLATILE;
--              ↑
--  "function" incurs a side-effect


-- Everybody is welcome as our customer, even bi-pedal dinosaurs!
--
SELECT new_ID('customer') AS customer, d.species
FROM   dinosaurs AS d
WHERE  d.legs = 2;

-- How is customer acquisition going?
TABLE issue;



-- Table-generating UDF (polymorphic): unnest a two-dimensional array
-- in column-major order:
--
CREATE OR REPLACE FUNCTION unnest2(xss anyarray)
  RETURNS SETOF anyelement AS
$$
SELECT xss[i][j]
FROM   generate_subscripts(xss,1) _(i),
       generate_subscripts(xss,2) __(j)
ORDER BY j, i  --  return elements in column-major order
$$
LANGUAGE SQL IMMUTABLE;

                    --  columns of 2D array
SELECT t.*          --      ↓   ↓   ↓
FROM   unnest2(array[array['a','b','c'],
                     array['d','e','f'],
                     array['x','y','z']])
       WITH ORDINALITY AS t(elem,pos);



--LATERAL : While using multiple tables with comma in FROM clause like below :
-- SELECT .... FROM Q1 AS t1,  Q2 AS t2,  Q3 AS t3
--SELECT t₁.tree, MAX(t₂.label) AS "largest label"
--FROM Trees AS t₁, unnest(t₁.labels) AS t₂(label)
--GROUP BY t₁.tree;
-- Dependent iteration ({{here}}:  t₂ depends on t₁ defined
--Exception: the arguments of table-generating functions may refer to row variables defined earlier (like t₁).

-- Use LATERAL for explicitly defining them
--Prefix  ⱼ with LATERAL in the FROM clause to announce dependent iteration:
--SELECT ⋯ FROM  Q₁ AS t₁, …, LATERAL  Qjⱼ AS tj, …

--Works for any table-valued SQL expression  ⱼ, subqueries in (⋯) in particular.
--Good style: be explicit and use LATERAL even with table-generating functions.

--SELECT  e FROM  Q₁ AS t₁, LATERAL  Q₂ AS t₂, LATERAL  Q₃ AS t₃
--is evaluated just like this nested loop:
--for Q₁ in  t₁
---for Q₂ in  t₂(t₁)
----for Q₃ in  t₃(t₁,t₂)
-----return  e(t₁,t₂,t₃)
-- Exception: dependent iteration OK in table-generating functions
--
SELECT t.tree, MAX(node.label) AS "largest label"
FROM   Trees AS t,
       LATERAL unnest(t.labels) AS node(label)  -- ⚠ refers to t.labels: dependent iteration
GROUP BY t.tree;


-- Equivalent reformulation (dependent iteration → subquery in SELECT)
--
SELECT t.tree, (SELECT MAX(node.label)
                FROM   unnest(t.labels) AS node(label)) AS "largest label"
FROM   Trees AS t
GROUP BY t.tree;


-- ⚠ This reformulation is only possible if the subquery yields
--   a scalar result (one row, one column) only ⇒ LATERAL is more general.
--   See the example (and its somewhat awkward reformulation) below.



-- Find the three tallest two- or four-legged dinosaurs:
--
SELECT locomotion.legs, tallest.species, tallest.height
FROM   (VALUES (2), (4)) AS locomotion(legs),
       LATERAL (SELECT d.*
                FROM   dinosaurs AS d
                WHERE  d.legs = locomotion.legs
                ORDER BY d.height DESC
                LIMIT 3) AS tallest;


-- Equivalent reformulation without LATERAL
--
WITH ranked_dinosaurs(species, legs, height, rank) AS (
  SELECT d1.species, d1.legs, d1.height,
         (SELECT COUNT(*)                          -- number of
          FROM   dinosaurs AS d2                   -- dinosaurs d2
          WHERE  d1.legs = d2.legs                 -- in d1's peer group
          AND    d1.height <= d2.height) AS rank   -- that are as large or larger as d1
  FROM   dinosaurs AS d1
  WHERE  d1.legs IS NOT NULL
)
SELECT d.legs, d.species, d.height
FROM   ranked_dinosaurs AS d
WHERE  d.legs IN (2,4)
AND    d.rank <= 3
ORDER BY d.legs, d.rank;

