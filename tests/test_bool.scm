(use-modules (aiscm element)
             (aiscm bool)
             (aiscm int)
             (aiscm jit)
             (oop goops)
             (guile-tap))
(planned-tests 34)
(define bool-false (make <bool> #:value #f))
(define bool-true (make <bool> #:value #t))
(ok (equal? bool-false bool-false)
    "equality of booleans")
(ok (not (equal? bool-false bool-true))
    "equality of booleans")
(ok (not (equal? bool-true bool-false))
    "equality of booleans")
(ok (equal? bool-true bool-true)
    "equality of booleans")
(ok (not (get bool-false))
    "get boolean value from bool-false")
(ok (get bool-true)
    "get boolean value from bool-true")
(ok (not (equal? bool-true bool-false))
    "unequal boolean objects")
(ok (eqv? 1 (size-of <bool>))
    "storage size of booleans")
(ok (equal? #vu8(0) (pack bool-false))
    "pack 'false' value")
(ok (equal? #vu8(1) (pack bool-true))
    "pack 'true' value")
(ok (eqv? 1 (size bool-true))
    "querying element size of boolean")
(ok (null? (shape bool-true))
    "querying shape of boolean")
(ok (equal? bool-false (unpack <bool> #vu8(0)))
    "unpack 'false' value")
(ok (equal? bool-true (unpack <bool> #vu8(1)))
    "unpack 'true' value")
(ok (equal? "#<<bool> #f>"
            (call-with-output-string (lambda (port) (display bool-false port))))
    "display boolean object")
(ok (equal? "#<<bool> #f>"
            (call-with-output-string (lambda (port) (write bool-false port))))
    "write boolean object")
(ok (equal? <bool> (match #f))
    "type matching for #f")
(ok (equal? <bool> (match #t))
    "type matching for #t")
(ok (equal? <bool> (match #f #t))
    "type matching for multiple booleans")
(ok (get bool-true)
    "get value of true")
(ok (not (get bool-false))
    "get value of false")
(ok (let [(b (make <bool> #:value #f))] (set b #t) (get b))
    "set boolean to true")
(ok (not (let [(b (make <bool> #:value #t))] (set b #f) (get b)))
    "set boolean to false")
(ok (set (make <bool> #:value #f) #t)
    "return value of setting boolean to true")
(ok (not (set (make <bool> #:value #t) #f))
    "return value of setting boolean to false")
(ok (equal? (make <bool> #:value #t) (build <bool> 1))
    "build boolean")
(ok (equal? '(0) (content #f))
    "'content' returns 0 for false")
(ok (equal? '(1) (content #t))
    "'content' returns 1 for true")
(ok (equal? '(#f #f #f #t) (map && '(#f #f #t #t) '(#f #t #f #t)))
    "'&&' behaves like 'and'")
(ok (not (&& #t #t #f))
    "'&&' with three arguments")
(ok (&& #t #t #t #t)
    "'&&' with four arguments")
(ok (equal? '(#f #t #t #t) (map || '(#f #f #t #t) '(#f #t #f #t)))
    "'||' behaves like 'or'")
(ok (not (|| #f #f #f))
    "'||' with three arguments")
(ok (|| #f #f #f #t)
    "'||' with four arguments")
