(define-module (aiscm float)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (system foreign)
  #:use-module (rnrs bytevectors)
  #:use-module (aiscm util)
  #:use-module (aiscm element)
  #:use-module (aiscm scalar)
  #:export (floating-point single-precision double-precision precision double?
            <float<>> <meta<float<>>>
            <float>  <float<single>> <meta<float<single>>>
            <double> <float<double>> <meta<float<double>>>))
(define single-precision 'single)
(define double-precision 'double)
(define-class* <float<>> <scalar> <meta<float<>>> <meta<scalar>>)
(define-method (write (self <float<>>) port)
  (format port "#<~a ~a>" (class-name (class-of self)) (get self)))
(define-generic precision)
(define (floating-point prec)
  (template-class (float prec) <float<>>
    (lambda (class metaclass)
      (define-method (precision (self metaclass)) prec) )))
(define <float>  (floating-point single-precision))
(define <double> (floating-point double-precision))
(define-method (foreign-type (t  <meta<float<single>>>)) float)
(define-method (foreign-type (t  <meta<float<double>>>)) double)
(define (double? self) (eq? double-precision (precision self)))
(define-method (size-of (self <meta<float<single>>>)) 4)
(define-method (size-of (self <meta<float<double>>>)) 8)
(define-method (pack (self <float<>>))
  (let* [(typecode (class-of self))
         (retval   (make-bytevector (size-of typecode)))
         (setter   (if (double? typecode)
                       bytevector-ieee-double-native-set!
                       bytevector-ieee-single-native-set!))]
    (setter retval 0 (get self))
    retval))
(define-method (unpack (self <meta<float<>>>) (packed <bytevector>))
  (let* [(ref   (if (double? self) bytevector-ieee-double-native-ref bytevector-ieee-single-native-ref))
         (value (ref packed 0))]
    (make self #:value value)))
(define-method (coerce (a <meta<float<>>>) (b <meta<float<>>>))
  (floating-point (if (or (double? a) (double? b)) double-precision single-precision)))
(define-method (native-type (i <real>) . args)
  (if (every real? args)
      <double>
      (apply native-type (sort-by-pred (cons i args) real?))))
(define-method (build (self <meta<float<>>>) value) (make self #:value value))
(define-method (content (self <real>)) (list self))
