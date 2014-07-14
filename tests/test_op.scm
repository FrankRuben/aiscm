(use-modules (oop goops)
             (aiscm element)
             (aiscm int)
             (aiscm sequence)
             (aiscm op)
             (guile-tap))
(planned-tests 35)
(define i1 (make <int> #:value (random (ash 1 29))))
(define i2 (make <int> #:value (random (ash 1 29))))
(define i3 (make <int> #:value (random (ash 1 29))))
(define l1 (make <long> #:value (random (ash 1 62))))
(define l2 (make <long> #:value (random (ash 1 62))))
(ok (eqv? (+ (get-value i1) (get-value i2)) (get-value (+ i1 i2)))
    "add two integers")
(ok (eqv? (+ (get-value l1) (get-value l2)) (get-value (+ l1 l2)))
    "add two long integers")
(ok (eqv? (+ (get-value i1) (get-value l2)) (get-value (+ i1 l2)))
    "add integer and long integer")
(ok (eqv? 64 (bits (class-of (+ i1 l1))))
    "check type coercion of addition")
(ok (eqv? (+ (get-value i1) (get-value i2) (get-value i3)) (get-value (+ i1 i2 i3)))
    "add three integers")
(ok (eqv? (+ (get-value i1)) (get-value (+ i1)))
    "unary plus")
(ok (eqv? (- (get-value i1) (get-value i2)) (get-value (- i1 i2)))
    "subtract two integers")
(ok (eqv? (+ (get-value i1) (get-value i2)) (get-value (+ i1 (get-value i2))))
    "add integer and Guile integer")
(ok (eqv? (+ (get-value i1) (get-value i2)) (get-value (+ (get-value i1) i2)))
    "add Guile integer and integer")
(ok (eqv? (- (get-value i1) (get-value i2)) (get-value (- i1 (get-value i2))))
    "subtract integer and Guile integer")
(ok (eqv? (- (get-value i1) (get-value i2)) (get-value (- (get-value i1) i2)))
    "subtract Guile integer and integer")
(ok (eqv? (- (get-value i1)) (get-value (- i1)))
    "negate integer")
(ok (equal? '(3 3 3) (multiarray->list (fill <int> 3 3)))
    "fill integer sequence")
(ok (equal? '(3 3 3) (multiarray->list (fill <sint> 3 3)))
    "fill short integer sequence")
(ok (equal? '(3 3 3) (multiarray->list (fill <byte> 3 3)))
    "fill byte sequence")
(ok (equal? '(3 3 3) (multiarray->list (fill <long> 3 3)))
    "fill long integer sequence")
(ok (equal? '(-3 -3 -3) (multiarray->list (- (fill <int> 3 3))))
    "negate integer sequence")
(ok (equal? '(-3 -3 -3) (multiarray->list (- (fill <sint> 3 3))))
    "negate short integer sequence")
(ok (equal? '(-3 -3 -3) (multiarray->list (- (fill <byte> 3 3))))
    "negate byte sequence")
(ok (equal? '(-3 -3 -3) (multiarray->list (- (fill <long> 3 3))))
    "negate long integer sequence")
(ok (equal? '(1 -2 -3) (multiarray->list (- (list->multiarray '(-1 2 3)))))
    "negate sequence")
(ok (equal? '(4 4 4) (multiarray->list (+ (fill <int> 3 3) 1)))
    "add integer to integer sequence")
(ok (equal? '(257 257 257) (multiarray->list (+ (fill <byte> 3 1) 256)))
    "add integer to byte sequence")
(ok (equal? '(257 257 257) (multiarray->list (+ 256 (fill <byte> 3 1))))
    "add byte sequence to integer")
(ok (equal? '(4 4 4) (multiarray->list (+ 1 (fill <int> 3 3))))
    "add integer sequence to integer")
(ok (equal? '(4 4 4) (multiarray->list (+ (fill <int> 3 1) (fill <int> 3 3))))
    "add integer sequences")
(ok (equal? '(4 4 4) (multiarray->list (+ (fill <byte> 3 1) (fill <sint> 3 3))))
    "add byte and short integer sequences")
(ok (equal? '(4 4 4) (multiarray->list (+ (fill <sint> 3 1) (fill <byte> 3 3))))
    "add short integer and byte sequences")
(ok (equal? '(255 254 253) (multiarray->list (+ (list->multiarray '(-1 -2 -3)) 256)))
    "sign-expand negative values when adding byte sequence and short integer")
(ok (equal? '(255 254 253) (multiarray->list (+ 256 (list->multiarray '(-1 -2 -3)))))
    "sign-expand negative values when adding short integer and byte sequence")
(ok (equal? '(255) (multiarray->list (+ (list->multiarray '(-1)) (list->multiarray '(256)))))
    "sign-expand negative values when adding byte sequence and short integer sequence")
(ok (equal? '(255) (multiarray->list (+ (list->multiarray '(256)) (list->multiarray '(-1)))))
    "sign-expand negative values when adding short integer sequence and byte sequence")
(ok (equal? '(-257 -256 -255) (multiarray->list (- (list->multiarray '(-1 0 1)) 256)))
    "element-wise subtract 1 from an array")
(ok (equal? '(256 255 254) (multiarray->list (- 256 (list->multiarray '(0 1 2)))))
    "element-wise subtract array from 256")
(ok (equal? '(2 1 0) (multiarray->list (- (list->multiarray '(4 5 6)) (list->multiarray '(2 4 6)))))
    "subtract an array from another")
(format #t "~&")
