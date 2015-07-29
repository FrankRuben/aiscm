(define-module (aiscm float)
  #:use-module (oop goops)
  #:use-module (system foreign)
  #:use-module (rnrs bytevectors)
  #:use-module (aiscm util)
  #:use-module (aiscm element)
  #:export (floating-point single-precision double-precision precision double?
            <float<>> <meta<float<>>>
            <float>  <float<single>> <meta<float<single>>>
            <double> <float<double>> <meta<float<double>>>))
(define single-precision 'single)
(define double-precision 'double)
(define-class* <float<>> (<element>) <meta<float<>>> (<meta<element>>))
(define-method (write (self <float<>>) port)
  (format port "#<~a ~a>" (class-name (class-of self)) (get-value self)))
(define-generic precision)
(define (floating-point prec)
  (let* [(name      (format #f "<float<~a>>" prec))
         (metaname  (format #f "<meta~a>" name))
         (metaclass (def-once metaname (make <class>
                                             #:dsupers (list <meta<float<>>>)
                                             #:name metaname)))
         (retval    (def-once name (make metaclass
                                         #:dsupers (list <float<>>)
                                         #:name name)))]
    (define-method (precision (self metaclass)) prec)
    retval))
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
    (setter retval 0 (get-value self))
    retval))
(define-method (unpack (self <meta<float<>>>) (packed <bytevector>))
  (let* [(ref   (if (double? self) bytevector-ieee-double-native-ref bytevector-ieee-single-native-ref))
         (value (ref packed 0))]
    (make self #:value value)))
(define-method (coerce (a <meta<float<>>>) (b <meta<float<>>>))
  (floating-point (if (or (double? a) (double? b)) double-precision single-precision)))
(define-method (match (i <real>) . args) <double>)
(define-method (types (self <meta<float<>>>)) (list self))
(define-method (content (self <real>)) (list self))
