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





