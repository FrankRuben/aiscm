(use-modules (aiscm obj)
             (aiscm element)
             (aiscm int)
             (aiscm jit)
             (aiscm asm)
             (oop goops)
             (system foreign)
             (guile-tap))
(define obj (make <obj> #:value 'sym))
(define address (pointer-address (scm->pointer 'sym)))
(define ctx (make <context>))

(ok (eqv? 8 (size-of <obj>))
    "size of SCM reference is 64 bits")
(ok (eq? <obj> (coerce <obj> <obj>))
    "objects coerce to objects")
(ok (eq? <obj> (coerce <obj> <int>))
    "object and integer coerce to object")
(ok (eq? <obj> (coerce <int> <obj>))
    "integer and object coerce to object")
(ok (equal? (make <obj> #:value 'sym) (build <obj> address))
    "build SCM value")
(ok (equal? (list address) (content <obj> 'sym))
    "content of symbol returns internal 64 bit representation")
(ok (eq? -124 ((jit ctx (list <obj>) (lambda (x) (call <obj> scm-lognot x))) 123))
    "compile and run bitwise not")
(ok (eq? 300 ((jit ctx (list <obj> <obj>) (lambda (x y) (call <obj> scm-sum x y))) 100 200))
    "compile and run call to scm_sum")
(ok (eq? 100 ((jit ctx (list <obj> <obj>) (lambda (x y) (call <obj> scm-difference x y))) 300 200))
    "compile and run call to scm_difference")
(skip (eq? -300 ((jit ctx (list <obj>) (lambda (x) (call <obj> scm-difference x scm-undefined))) 300))
    "compile and run call to scm_difference with one argument")
(ok (eq? 600 ((jit ctx (list <obj> <obj>) (lambda (x y) (call <obj> scm-product x y))) 20 30))
    "compile and run call to scm_product")
(ok (eq? 30 ((jit ctx (list <obj> <obj>) (lambda (x y) (call <obj> scm-divide x y))) 600 20))
    "compile and run call to scm_divide")
(ok (eq? 33 ((jit ctx (list <obj> <obj>) (lambda (x y) (call <obj> scm-remainder x y))) 123 45))
    "compile and run call to scm_remainder")
(ok (eq? 72 ((jit ctx (list <obj> <obj>) (lambda (x y) (call <obj> scm-logand x y))) 123 456))
    "compile and run call to scm_logand")
(ok (eq? 507 ((jit ctx (list <obj> <obj>) (lambda (x y) (call <obj> scm-logior x y))) 123 456))
    "compile and run call to scm_logior")
(ok (eq? 435 ((jit ctx (list <obj> <obj>) (lambda (x y) (call <obj> scm-logxor x y))) 123 456))
    "compile and run call to scm_logxor")
(run-tests)
