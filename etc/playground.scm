(use-modules (oop goops)
             (srfi srfi-1)
             (srfi srfi-26)
             (srfi srfi-64)
             (system foreign)
             (aiscm element)
             (aiscm int)
             (aiscm sequence)
             (aiscm mem)
             (aiscm pointer)
             (aiscm rgb)
             (aiscm complex)
             (aiscm obj)
             (aiscm asm)
             (aiscm jit)
             (aiscm method)
             (aiscm util))

(test-begin "playground")

;(define-method (tensor-op name . args)
;  (if (not (defined? name))
;    (let [(f (jit ctx (map class-of args) (car args)))]
;      (add-method! name (make <method> #:specializers (map class-of args)
;                                       #:procedure (lambda args (apply f args))))))
;  (apply (eval name (current-module)) args))
;
;(define-macro (tensor expr) `(tensor-op '- ,expr))
;
;(define s (seq 2 3 5))
;
;(tensor s)

(define (tensor-operation? expr)
  "Check whether expression is a tensor operation"
  (and (list? expr) (memv (car expr) '(+ -))))

(define (expression->identifier expr)
  "Extract structure of tensor and convert to identifier"
  (if (tensor-operation? expr)
      (string-append "("
                     (symbol->string (car expr))
                     " "
                     (string-join (map expression->identifier (cdr expr)))
                     ")")
      "_"))

(define (tensor-variables expr)
  "Return variables of tensor expression"
  (if (tensor-operation? expr) (map tensor-variables (cdr expr)) expr))

(define (identifier->expression identifier variables)
  "Convert identifier to tensor expression with variables"
  (if (equal? "(" (string-take identifier 1))
      (cons (string->symbol (substring identifier 1 2)) variables)
      variables))

(test-begin "identify tensor operations")
  (test-assert "+ is a tensor operation"
    (tensor-operation? '(+ x y)))
  (test-assert "- is a tensor operation"
    (tensor-operation? '(- x)))
  (test-assert "x is not a tensor operation"
    (not (tensor-operation? 'x)))
  (test-assert "read-image is not a tensor operation"
    (not (tensor-operation? '(read-image "test.bmp"))))
(test-end "identify tensor operations")

(test-begin "convert tensor expression to identifier")
  (test-equal "filter variable names in expression"
    "_" (expression->identifier 'x))
  (test-equal "filter numeric arguments of expression"
    "_" (expression->identifier 42))
  (test-equal "preserve unary plus operation"
    "(+ _)" (expression->identifier '(+ x)))
  (test-equal "preserve unary minus operation"
    "(- _)" (expression->identifier '(- x)))
  (test-equal "preserve binary plus operation"
    "(+ _ _)" (expression->identifier '(+ x y)))
  (test-equal "works recursively"
    "(+ (- _) _)" (expression->identifier '(+ (- x) y)))
  (test-equal "filter non-tensor operations"
    "_" (expression->identifier '(read-image "test.bmp")))
(test-end "convert tensor expression to identifier")

(test-begin "extract variables of tensor expression")
  (test-equal "detect variable name"
    'x (tensor-variables 'x))
  (test-equal "detect numerical arguments"
    42 (tensor-variables 42))
  (test-equal "extract argument of unary plus"
    '(x) (tensor-variables '(+ x)))
  (test-equal "extract argument of unary minus"
    '(x) (tensor-variables '(- x)))
  (test-equal "extract arguments of binary plus"
    '(x y) (tensor-variables '(+ x y)))
  (test-equal "extract variables recursively"
    '((x) y) (tensor-variables '(+ (- x) y)))
  (test-equal "extract non-tensor operations"
    '(read-image "test.bmp") (tensor-variables '(read-image "test.bmp")))
(test-end "extract variables of tensor expression")

(test-begin "convert tensor identifier to tensor expression")
  (test-equal "single variable expression"
    'x (identifier->expression "_" 'x))
  (test-equal "use provided variable names"
    'y (identifier->expression "_" 'y))
  (test-equal "reconstruct unary plus operation"
    '(+ x) (identifier->expression "(+ _)" '(x)))
  (test-equal "reconstruct unary minus operation"
    '(- x) (identifier->expression "(- _)" '(x)))
  (test-equal "reconstruct binary plus operation"
    '(+ x y) (identifier->expression "(+ _ _)" '(x y)))
(test-end "convert tensor identifier to tensor expression")

(test-end "playground")
