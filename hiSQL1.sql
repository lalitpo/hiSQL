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
VALUES(5,'x','T',NULL),(4,'y','F',20),(3,'x','F',30),(2,'y','T',40),(1,'x','T',10);

TABLE DISTABLE;

SELECT DISTINCT ON (t.c) t.*
FROM DISTABLE AS t
ORDER BY t.c, t.d ASC;
 

/*SELECT DISTINCT  :  Extracts only one row among a group of duplicate rows. 
No ORDER BY is required.


AGGREGATES :  Summation, maximum, average, etc.
Cannot mix aggregates with non-aggregate expressions <e> in SELECT clause 
*/