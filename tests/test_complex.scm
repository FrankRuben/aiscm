(use-modules (oop goops)
             (srfi srfi-26)
             (aiscm composite)
             (aiscm complex)
             (aiscm element)
             (aiscm int)
             (aiscm obj)
             (aiscm float)
             (aiscm pointer)
             (aiscm sequence)
             (aiscm asm)
             (aiscm jit)
             (guile-tap))
(define ctx (make <context>))
(define v (make (complex <byte>) #:value 2+3i))
(define r (make (complex <byte>) #:value 5))
(ok (eq? (complex <int>) (complex <int>))
    "equality of complex types")
(ok (eqv? 2 (size-of (complex <byte>)))
    "storage size of byte complex")
(ok (eqv? 8 (size-of (complex <float>)))
    "storage size of single-precision floating-point complex")
(ok (eq? <int> (base (complex <int>)))
    "base of integer complex type")
(ok (equal? #vu8(#x02 #x03) (pack v))
    "pack complex value")
(ok (equal? #vu8(#x05 #x00) (pack r))
    "pack complex value with zero imaginary component")
(ok (equal? v (unpack (complex <byte>) #vu8(#x02 #x03)))
    "unpack complex value")
(ok (null? (shape v))
    "complex has no dimensions")
(ok (eq? (complex <byte>) (coerce (complex <byte>) <byte>))
    "coerce complex and scalar type")
(ok (eq? (complex <byte>) (coerce <byte> (complex <byte>)))
    "coerce scalar type and complex")
(ok (eq? (complex <int>) (coerce (complex <byte>) (complex <usint>)))
    "coerce different complex types")
(ok (eq? (sequence (complex <sint>)) (complex <sint> (sequence <ubyte>)))
    "coerce complex array from array types")
(ok (eq? (multiarray (complex <int>) 2) (complex <sint> (multiarray <usint> 2)))
    "coerce 2D complex array from array types")
(ok (eq? (sequence (complex <int>)) (coerce (sequence <int>) (complex <int>)))
    "coerce integer sequence and complex type")
(ok (eq? (sequence (complex <int>)) (coerce (complex <int>) (sequence <int>)))
    "coerce complex type and integer sequence")
(ok (eq? (multiarray (complex <int>) 2) (coerce (complex <int>) (multiarray <int> 2)))
    "coerce complex type and 2D array")
(ok (equal? (list 2 3) (content (complex <int>) 2+3i))
    "'content' extracts the components of a complex value")
(ok (eq? (complex <ubyte>) (native-type 2+3i))
    "type matching for 2+3i")
(skip (eq? (complex <double>) (native-type 2+3i 1.2))
    "type matching for complex value and scalar")
(skip (eq? (complex <double>) (native-type 1.2 2+3i))
    "type matching for scalar and complex value")
(ok (eq? (sequence <int>) (base (sequence (complex <int>))))
    "base type of sequence applies to element type")
(ok (eqv? 2-3i (conj 2+3i))
    "conjugate of complex number")
(ok (eqv? 2+3i ((jit ctx (list (complex <int>)) identity) 2+3i))
    "Return complex number")
(ok (eqv? 2 ((jit ctx (list (complex <int>)) real-part) 2+3i))
    "Extract real component in compiled code")
(ok (equal? '(2 5) (to-list (real-part (seq 2+3i 5+7i))))
    "Real part of complex array")
(ok (eqv? 3 ((jit ctx (list (complex <int>)) imag-part) 2+3i))
    "Extract imaginary component in compiled code")
(ok (equal? '(3 7) (to-list (imag-part (seq 2+3i 5+7i))))
    "Imaginary part of complex array")
(ok (equal? 2+3i ((jit ctx (list <int> <int>) (lambda (re im) (complex re im))) 2 3))
    "compose complex value in compiled code")
(ok (equal? 2+3i ((jit ctx (list (complex <ubyte>)) (cut to-type (complex <int>) <>)) 2+3i))
    "convert byte complex to integer complex")
(ok (eqv? 7+10i ((jit ctx (list (complex <int>) (complex <int>)) +) 2+3i 5+7i))
    "add complex values")
(ok (eqv? 6+3i ((jit ctx (list (complex <int>) <int>) +) 2+3i 4))
    "add complex and real value")
(ok (eqv? 5+4i ((jit ctx (list <int> (complex <int>)) +) 2 3+4i))
    "add real and complex value")
(ok (eqv? -2-3i ((jit ctx (list (complex <int>)) -) 2+3i))
    "negate complex number")
(ok (eqv? -11+29i ((jit ctx (list (complex <int>) (complex <int>)) *) 2+3i 5+7i))
    "multiply complex numbers")
(ok (eqv? 10+15i ((jit ctx (list (complex <int>) <int>) *) 2+3i 5))
    "multiply complex numbers and real value")
(ok (eqv? 6+10i ((jit ctx (list <int> (complex <int>)) *) 2 3+5i))
    "multiply real number and complex number")
(ok (eqv? 5+7i ((jit ctx (list (complex <int>) (complex <int>)) /) -11+29i 2+3i))
    "divide complex numbers")
(ok (eqv? 2+3i ((jit ctx (list (complex <int>) <int>) /) 4+6i 2))
    "divide complex number by number")
(ok (eqv? 3-4i ((jit ctx (list <int> (complex <int>)) /) 25 3+4i))
    "divide number by complex number")
(ok (eqv? 42 ((jit ctx (list <int>) real-part) 42))
    "get real part of real number")
(ok (equal? '(2 3 5) (to-list (real-part (seq 2 3 5))))
    "real part of array is array")
(ok (equal? '(0 0 0) (to-list ((jit ctx (list (sequence <int>)) imag-part) (seq <int> 2 3 5))))
    "Compile code to get imaginary part of real array")
(ok (equal? '(0 0 0) (to-list (imag-part (seq 2 3 5))))
    "imaginary part of array is array of zeros")
(ok (eqv? 0 ((jit ctx (list <int>) imag-part) 42))
    "get imaginary part of real number")
(ok (eqv? 2-3i ((jit ctx (list (complex <int>)) conj) 2+3i))
    "complex conjugate")
(ok (eqv? 2 ((jit ctx (list <int>) conj) 2))
    "conjugate of real number")
(let [(c (parameter (complex <int>)))]
  (ok (is-a? (decompose-value (complex <int>) c) <internalcomplex>)
      "Decompose complex parameters into internal complex values"))
(ok (pointerless? (complex <int>))
    "complex integer memory is pointerless")
(ok (not (pointerless? (complex <obj>)))
    "complex object memory is not pointerless")
(ok (eqv? 2 ((jit ctx (list (complex <obj>)) real-part) 2+3i))
    "extract real part of object RGB")
(ok (equal? (list real-part imag-part) (components <complex<>>))
    "components of complex values are real-part and imag-part")
(run-tests)
