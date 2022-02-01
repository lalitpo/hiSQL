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
 
