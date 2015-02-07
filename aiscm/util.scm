(define-module (aiscm util)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (ice-9 curried-definitions)
  #:use-module (rnrs bytevectors)
  #:use-module (system foreign)
  #:export (toplevel-define! malloc destroy attach index all-but-last repeat depth
            flatten-n flatten cycle uncycle integral zipmap alist-invert
            assq-set assv-set assoc-set product sort-by argmin argmax
            nodes adjacent remove-node color-graph union difference fixed-point)
  #:export-syntax (def-once expand))
(define (toplevel-define! name val)
  (module-define! (current-module) name val))
(define-syntax-rule (def-once name value)
  (let [(sym (string->symbol name))]
    (if (not (defined? sym (current-module)))
      (toplevel-define! sym value))
    (primitive-eval sym)))
(define (malloc size) (bytevector->pointer (make-bytevector size)))
(define-generic destroy)
(define (attach lst x) (reverse (cons x (reverse lst))))
(define (index a b)
  (let [(tail (member a (reverse b)))]
    (if tail (length (cdr tail)) #f)))
(define (all-but-last lst) (reverse (cdr (reverse lst))))
(define (repeat x n) (if (zero? n) '() (cons x (repeat x (1- n)))))
(define-syntax-rule (expand n expr) (map (lambda (tmp) expr) (iota n)))
(define (depth val)
  (if (list? val) (1+ (apply max (cons 0 (map depth val)))) 0))
(define (flatten-n val n)
  (if (> (depth val) n)
    (if (> (depth (car val)) (- n 1))
      (flatten-n (append (car val) (cdr val)) n)
      (cons (car val) (flatten-n (cdr val) n)))
    val))
(define (flatten val) (flatten-n val 1))
(define (cycle lst) (attach (cdr lst) (car lst)))
(define (uncycle lst) (cons (last lst) (all-but-last lst)))
(define (integral lst)
  (letrec [(accumulate (lambda (lst x)
                         (if (null? lst)
                           lst
                           (let [(xs (+ (car lst) x))]
                             (cons xs (accumulate (cdr lst) xs))))))]
    (accumulate lst 0)))
(define (zipmap keys vals) (map (lambda (x) (cons (car x) (cadr x))) (zip keys vals)))
(define (alist-invert alist)
  (map (lambda (x) (cons (cdr x) (car x))) alist))
(define (alist-set = alist key val)
  (if (null? alist)
    (list (cons key val))
    (if (= (caar alist) key)
      (cons (cons key val) (cdr alist))
      (cons (car alist) (assq-set (cdr alist) key val)))))
(define (assq-set alist key val) (alist-set eq? alist key val))
(define (assv-set alist key val) (alist-set eqv? alist key val))
(define (assoc-set alist key val) (alist-set equal? alist key val))
(define (product lst1 lst2) (concatenate (map (lambda (x) (map (cut cons x <>) lst2)) lst1)))
(define (sort-by lst fun) (sort-list lst (lambda args (apply < (map fun args)))))
(define (argop op fun lst)
  (let* [(vals  (map fun lst))
         (opval (apply op vals))]
    (list-ref (reverse lst) (1- (length (member opval vals))))))
(define (argmin fun lst) (argop min fun lst))
(define (argmax fun lst) (argop max fun lst))
(define (fixed-point initial iteration compare?)
  (let [(successor (iteration initial))]
    (if (compare? initial successor)
      initial
      (fixed-point successor iteration compare?))))
(define (union . args) (apply lset-union (cons eq? args)))
(define (difference . args) (apply lset-difference (cons eq? args)))
(define (nodes graph) (delete-duplicates (append (map car graph) (map cdr graph))))
(define ((has-node? node) edge) (or (eq? (car edge) node) (eq? (cdr edge) node)))
(define ((adjacent graph) node) (nodes (filter (has-node? node) graph)))
(define (remove-node graph node) (filter (compose not (has-node? node)) graph))
(define (color-nodes graph nodes predefined colors)
  (if (null? nodes) predefined
    (let* [(target    (argmin (compose length (adjacent graph)) nodes))
           (coloring  (color-nodes (remove-node graph target) (delete target nodes) predefined colors))
           (blocked   (map (cut assq-ref coloring <>) ((adjacent graph) target)))
           (available (difference colors blocked))]
      (cons (cons target (car available)) coloring))))
(define (color-graph graph colors predefined)
  (color-nodes graph
               (difference (nodes graph) (map car predefined))
               predefined
               colors))
