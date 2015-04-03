(use-modules (srfi srfi-1)
             (aiscm util)
             (guile-tap))
(planned-tests 31)
(toplevel-define! 'a 0)
(def-once "x" 1)
(def-once "x" 2)
(ok (eqv? 0 a)
    "'toplevel-define! should create a definition for the given symbol")
(ok (eqv? 1 x)
    "'def-once' should only create a definition once")
(ok (equal? '(1 2 3) (attach '(1 2) 3))
    "'attach' should add an element at the end of the list")
(ok (not (index 4 '(2 3 5 7)))
    "'index' returns #f if value is not element of list")
(ok (eqv? 2 (index 5 '(2 3 5 7)))
    "'index' returns index of first matching list element")
(ok (equal? '(2 3 5) (all-but-last '(2 3 5 7)))
    "'all-but-last' should return a list with the last element removed")
(ok (equal? '() (drop-up-to '(1 2 3) 4))
    "'drop-up-to' returns empty list if drop count is larger than length of list")
(ok (equal? '(5 6) (drop-up-to '(1 2 3 4 5 6) 4))
    "'drop-up-to' behaves like 'drop' otherwise")
(ok (equal? '(1 1 1) (expand 3 1))
    "'expand' should create a list of repeating elements")
(ok (equal? '(1 2 3 4) (flatten '(1 (2 3) ((4)))))
    "'flatten' flattens a list")
(ok (equal? '(2 3 4 1) (cycle '(1 2 3 4)))
    "'cycle' should cycle the elements of a list")
(ok (equal? '(4 1 2 3) (uncycle '(1 2 3 4)))
    "'uncycle' should reverse cycle the elements of a list")
(ok (equal? '(1 3 6 10) (integral '(1 2 3 4)))
    "'integral' should compute the accumulative sum of a list")
(ok (equal? '((1 . a) (2 . b)) (alist-invert '((a . 1) (b . 2))))
    "'alist-invert' should invert an association list")
(ok (equal? '((3 . c)) (assq-set '() 3 'c))
    "'assq-set' should work with empty association list")
(ok (equal? '((1 . a) (2 . b) (3 . c)) (assq-set '((1 . a) (2 . b)) 3 'c))
    "'assq-set' should append new associations")
(ok (equal? '((1 . a) (2 . c)) (assq-set '((1 . a) (2 . b)) 2 'c))
    "'assq-set' should override old associations")
(ok (equal? '((a . 1) (a . 2) (a . 3) (b . 1) (b . 2) (b . 3)) (product '(a b) '(1 2 3)))
    "'product' should create a product set of two lists")
(ok (equal? '((a . 1) (b . 2) (c . 3)) (sort-by '((c . 3) (a . 1) (b . 2)) cdr))
    "'sort-by' should sort arguments by the values of the supplied function")
(ok (equal? '(a . 1) (argmin cdr '((c . 3) (a . 1) (b . 2))))
    "Get element with minimum of argument")
(ok (equal? '(c . 3) (argmax cdr '((c . 3) (a . 1) (b . 2))))
    "Get element with minimum of argument")
(ok (equal? '((0 1) (2 3 4) (5 6 7 8 9)) (gather '(2 3 5) (iota 10)))
    "'gather' groups elements into groups of specified size")
(ok (< (abs (- (sqrt 2)
               (fixed-point 1 (lambda (x) (* 0.5 (+ (/ 2 x) x))) (lambda (a b) (< (abs (- a b)) 1e-5)))))
       1e-5)
    "Fixed point iteration")
(ok (lset= eqv? '(1 2 3) (union '(1 2) '(2 3)))
    "'union' should merge two sets")
(ok (lset= eqv? '(1) (difference '(1 2) '(2 3)))
    "'difference' should return the set difference")
(ok (lset= eq? '(a b c d) (nodes '((b . a) (a . c) (d . c))))
    "'nodes' should return the nodes of a graph")
(ok (lset= eq? '(a b c) ((adjacent '((b . a) (a . c) (d . c))) 'a))
    "'adjacent' should return a list of adjacent nodes")
(ok (equal? '((d . c)) (remove-node '((b . a) (a . c) (d . c)) 'a))
    "'remove-node' should return a subgraph with node and connecting edges removed")
(ok (equal? '((b . red) (a . green) (d . green) (c . red))
            (color-graph '((b . a) (a . c) (d . c)) '(red green blue)))
    "'color-graph' should color adjacent nodes of a graph differently")
(ok (equal? '((b . green) (a . red) (c . green) (d . red))
            (color-graph '((b . a) (a . c) (d . c)) '(red green blue) #:predefined '((d . red))))
    "'color-graph' should respect predefined colors")
(ok (not (color-graph '((a . b)) '(red)))
    "'color-graph' should return false if running out of registers")
