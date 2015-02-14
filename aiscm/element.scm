(define-module (aiscm element)
  #:use-module (oop goops)
  #:use-module (system foreign)
  #:export (<element>
            <meta<element>>
            get-value size-of foreign-type pack unpack
            typecode size shape strides dimension coerce match get set get-size
            types content param))
(define-class <meta<element>> (<class>))
(define-class <element> ()
              (value #:init-keyword #:value #:getter get-value)
              #:metaclass <meta<element>>)
(define-generic size-of)
(define-method (foreign-type (t <class>)) void)
(define-generic pack)
(define-generic unpack)
(define-method (equal? (a <element>) (b <element>))
  (equal? (get-value a) (get-value b)))
(define-method (size (self <element>)) 1)
(define-method (shape self) '())
(define-method (strides self) '())
(define-method (dimension (self <meta<element>>)) 0)
(define-method (dimension (self <element>)) (dimension (class-of self)))
(define-method (typecode (self <meta<element>>)) self)
(define-method (typecode (self <element>)) (typecode (class-of self)))
(define-generic slice)
(define-generic coerce)
(define-generic match)
(define-method (get (self <element>)) (get-value self))
(define-method (set (self <element>) o) (begin (slot-set! self 'value o)) o)
(define-generic get-size)
(define-generic types)
(define-generic content)
(define-method (param (self <meta<element>>) lst) (car lst))
