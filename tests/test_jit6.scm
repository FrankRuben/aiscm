(use-modules (oop goops)
             (system foreign)
             (srfi srfi-1)
             (srfi srfi-26)
             (aiscm element)
             (aiscm sequence)
             (aiscm int)
             (aiscm bool)
             (aiscm obj)
             (aiscm rgb)
             (aiscm asm)
             (aiscm jit)
             (guile-tap))

(load-extension "libguile-aiscm-tests" "init_tests")

(define ctx (make <context>))
(define guile-aiscm-tests   (dynamic-link "libguile-aiscm-tests"))
(define jit-side-effect     (dynamic-func "jit_side_effect"     guile-aiscm-tests))
(define jit-constant-fun    (dynamic-func "jit_constant_fun"    guile-aiscm-tests))
(define jit-subtracting-fun (dynamic-func "jit_subtracting_fun" guile-aiscm-tests))
(define jit-seven-arguments (dynamic-func "jit_seven_arguments" guile-aiscm-tests))
(define jit-boolean-not     (dynamic-func "jit_boolean_not"     guile-aiscm-tests))

(define main (dynamic-link))
(define cabs (dynamic-func "abs" main))

(ok (equal? (MOV AX 0) (fix-stack-position (MOV AX 0) 123))
    "setting stack position does not affect operations not involving pointers")
(ok (equal? (MOV (ptr <byte> RSP 0) AL) (fix-stack-position (MOV (ptr <byte> stack-pointer 0) AL) 0))
    "setting stack position replaces the stack pointer placeholder with RSP")
(let [(p (var <long>))]
  (ok (equal? (MOV (ptr <byte> p) AL) (fix-stack-position (MOV (ptr <byte> p) AL) 0))
      "setting stack position ignores other pointer variables"))
(ok (equal? (MOV (ptr <byte> RSP 8) AL) (fix-stack-position (MOV (ptr <byte> stack-pointer 0) AL) -8))
    "setting stack position takes the pointer offset into account")
(ok (equal? (MOV (ptr <byte> RSP 24) AL) (fix-stack-position (MOV (ptr <byte> stack-pointer 8) AL) -16))
    "stack pointer adjustment and pointer offset get added")
(ok (equal? (list (MOV (ptr <byte> RSP 0) AL)) (fix-stack-position (list (MOV (ptr <byte> stack-pointer 0) AL)) 0))
    "apply stack position adjustment to each command in a list")
(ok (equal? (list (SUB RSP 8) (NOP) (ADD RSP 8) (RET)) (position-stack-frame (list (NOP) (RET)) -8))
    "positioning the stack pointer replaces the stack-pointer place holder")
(ok (equal? (list (SUB RSP 8) (MOV (ptr <byte> RSP 24) AL) (ADD RSP 8) (RET))
            (position-stack-frame (list (MOV (ptr <byte> stack-pointer 16) AL) (RET)) -8))
    "positioning the stack pointer also adjusts pointer offsets")
(let [(a (parameter <int>))]
  (ok (equal? (MOV EDI (get (delegate a))) (car (pass-parameters (list a) (NOP))))
      "Passing register parameters creates copy instructions"))
(let [(args (map parameter (make-list 7 <int>)))]
  (ok (equal? (PUSH (get (delegate (list-ref args 6)))) (list-ref (pass-parameters args (NOP)) 6))
      "Passing stack parameters pushes the parameters on the stack")
  (ok (equal? (ADD RSP #x08) (last (pass-parameters args (NOP))))
      "Stack pointer gets corrected after stack parameters have been used"))
(ok (equal? 42 ((jit ctx '() (const (call <int> '() jit-constant-fun)))))
    "Compile method call to function returning constant value")
(ok (equal? 63 ((jit ctx (list <int>) (lambda (x) (+ x (call <int> (list <int>) jit-constant-fun)))) 21))
    "Compile function call and plus operation to test that caller-saved registers get blocked")
(ok (equal? 2 ((jit ctx (list <int> <int>) (lambda (x y) (call <int> (list <int> <int>) jit-subtracting-fun y x))) 5 7))
    "Compile function call taking two arguments")
(ok (equal? 5 ((jit ctx (make-list 3 <int>) (lambda (x y z) (call <int> (list <int> <int>) jit-subtracting-fun x (+ y z)))) 10 2 3))
    "Pass result of expression to function call")
(ok (equal? 42 ((jit ctx (list <int> <int>) (lambda (a b) (call <int> (make-list 7 <int>) jit-seven-arguments a a a a a a b))) 123 42))
    "Compile function call with seven arguments (requires stack parameters)")
(ok (equal? '(#t #f) (map (jit ctx (list <bool>) (cut call <bool> (list <bool>) jit-boolean-not <>)) '(#f #t)))
    "Compile and run native boolean negation function")
(ok (equal? 42 ((jit ctx (list <int>) (cut call <int> (list <int>) cabs <>)) -42))
    "call C standard library abs function")
(ok (eq? <ulong> (typecode (var <obj>)))
    "Scheme objects are represented using unsigned 64-bit integers")
(let [(o (skeleton <obj>))]
  (ok (is-a? o <obj>)
      "skeleton of top object is of type obj")
  (ok (is-a? (value o) <var>)
      "value of object skeleton is a variable")
  (ok (eq? <ulong> (typecode (value o)))
      "value of object skeleton is of type unsigned long integer"))
(ok (is-a? (car (content <obj> (var <long>))) <var>)
    "do not decompose variables")
(ok (eq? 'symbol ((jit ctx (list <obj>) identity) 'symbol))
    "compile and run identity function accepting Scheme object")
(ok (eq? 42 ((jit ctx (list <obj>) identity) 42))
    "make sure \"content\" enforces SCM object arguments")
(ok (eq? -300 ((jit ctx (list <obj>) -) 300))
    "negation of Scheme object")
(ok (eq? -124 ((jit ctx (list <obj>) ~) 123))
    "bitwise logical not using Scheme objects")
(ok (equal? '(#f #t) (map (jit ctx (list <obj>) =0) '(3 0)))
    "comparison of Scheme object with zero")
(ok (equal? '(#t #f) (map (jit ctx (list <obj>) !=0) '(3 0)))
    "Scheme object not equal to zero")
(ok (equal? '(#t #f #f #f #f) (map (jit ctx (list <obj>) !) '(#f #t () 0 1)))
    "compiled logical not for Scheme objects")
(ok (eq? 300 ((jit ctx (list <obj> <obj>) +) 100 200))
    "compiled plus operation using Scheme objects")
(ok (eq? 300 ((jit ctx (list <obj>) +) 300))
    "compiled unary plus using Scheme objects")
(ok (eq? 100 ((jit ctx (list <obj> <obj>) -) 300 200))
    "compiled minus operation using Scheme objects")
(ok (eq? 600 ((jit ctx (list <obj> <obj>) *) 20 30))
    "compiled multiplication using Scheme objects")
(ok (eq? 5 ((jit ctx (list <obj> <obj>) /) 15 3))
    "compiled division using Scheme objects")
(ok (eq? 33 ((jit ctx (list <obj> <obj>) %) 123 45))
    "compiled modulo using Scheme objects")
(ok (eq? 72 ((jit ctx (list <obj> <obj>) &) 123 456))
    "bitwise and using Scheme objects")
(ok (eq? 507 ((jit ctx (list <obj> <obj>) |) 123 456))
    "bitwise or using Scheme objects")
(ok (eq? 435 ((jit ctx (list <obj> <obj>) ^) 123 456))
    "bitwise exclusive-or using Scheme objects")
(ok (equal? '(#f b) (map (jit ctx (list <obj> <obj>) &&) '(#f a) '(b b)))
    "logical and for Scheme objects")
(ok (equal? '(b a) (map (jit ctx (list <obj> <obj>) ||) '(#f a) '(b b)))
    "logical or for Scheme objects")
(ok (eq? 123 ((jit ctx (list <obj> <obj>) min) 123 456))
    "compiled minimum using Scheme objects")
(ok (eq? 456 ((jit ctx (list <obj> <obj>) max) 123 456))
    "compiled maximum using Scheme objects")
(ok (eq? 1968 ((jit ctx (list <obj> <obj>) <<) 123 4))
    "compiled shift-left using Scheme objects")
(ok (eq? 123 ((jit ctx (list <obj> <obj>) >>) 1968 4))
    "compiled shift-right using Scheme objects")
(ok (equal? (list #f #t) (map (jit ctx (list <obj> <obj>) =) '(21 42) '(42 42)))
    "compiled equal comparison of Scheme objects")
(ok (equal? (list #t #f) (map (jit ctx (list <obj> <obj>) !=) '(21 42) '(42 42)))
    "compiled unequal comparison of Scheme objects")
(ok (equal? (list #t #f #f) (map (jit ctx (list <obj> <obj>) <) '(3 5 7) '(5 5 5)))
    "compiled lower-than comparison for Scheme objects")
(ok (equal? (list #t #t #f) (map (jit ctx (list <obj> <obj>) <=) '(3 5 7) '(5 5 5)))
    "compiled lower-equal comparison for Scheme objects")
(ok (equal? (list #f #f #t) (map (jit ctx (list <obj> <obj>) >) '(3 5 7) '(5 5 5)))
    "compiled greater-than comparison for Scheme objects")
(ok (equal? (list #f #t #t) (map (jit ctx (list <obj> <obj>) >=) '(3 5 7) '(5 5 5)))
    "compiled greater-equal comparison for Scheme objects")
(ok (eq? 42 ((jit ctx (list <obj>) (cut to-type <int> <>)) 42))
    "convert Scheme object to integer in compiled code")
(ok (equal? '(2 3 5) (to-list ((jit ctx (list (sequence <obj>)) identity) (seq <obj> 2 3 5))))
    "compile and run identity function for sequence of objects")
(ok (equal? '(-3 -4 -6) (to-list ((jit ctx (list (sequence <obj>)) ~) (seq <obj> 2 3 5))))
    "dereference pointer when doing bitwise negation")
(ok (equal? '(#f #t) (map (jit ctx (list <ubyte>) (cut to-type <bool> <>)) '(0 1)))
    "convert unsigned byte to boolean")
(ok (equal? '(#f #t) (map (jit ctx (list <int>) (cut to-type <bool> <>)) '(0 1)))
    "convert integer to boolean")
(ok (equal? '(0 1) (map (jit ctx (list <bool>) (cut to-type <ubyte> <>)) '(#f #t)))
    "convert boolean to unsigned byte")
(ok (eqv? 42 ((jit ctx (list <int>) (cut to-type <obj> <>)) 42))
    "convert integer to object")
(ok (equal? '(#f #t) (map (jit ctx (list <obj>) (cut to-type <bool> <>)) '(#f #t)))
    "convert object to boolean")
(ok (equal? '(#f #t) (map (jit ctx (list <bool>) (cut to-type <obj> <>)) '(#f #t)))
    "convert boolean to object")
(ok (equal? (list (rgb 2 3 5)) (to-list (to-type (rgb <obj>) (seq (rgb 2 3 5)))))
    "convert integer RGB sequence to object RGB sequence")
(ok (equal? (list (rgb 2 3 5)) (to-list (to-type (rgb <int>) (seq (rgb <obj>) (rgb 2 3 5)))))
    "convert object RGB sequence to integer RGB sequence")
(skip (eqv? 7 ((jit ctx (list <obj> <int>) |) 3 6))
    "bitwise or for object and integer")
(run-tests)
