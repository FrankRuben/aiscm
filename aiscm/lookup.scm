(define-module (aiscm lookup)
  #:use-module (oop goops)
  #:use-module (aiscm element)
  #:use-module (aiscm pointer)
  #:use-module (aiscm var)
  #:export (<lookup>
            make-lookup
            get-var
            get-stride
            get-length))
(define-class <lookup> (<element>)
  (var #:init-keyword #:var #:getter get-var)
  (stride #:init-keyword #:stride #:getter get-stride))
(define (make-lookup value var stride)
  (make <lookup> #:value value #:var var #:stride stride))
(define-method (equal? (a <lookup>) (b <lookup>))
  (and
    (next-method)
    (equal? (get-var a) (get-var b))
    (equal? (get-stride a) (get-stride b))))
(define-method (lookup (self <pointer<>>) (var <var>) (stride <integer>))
  (make-lookup self var stride))
;(define-method (skip (self <pointer<>>) (offset <integer>))
;  (make-lookup (lookup (get-value self) offset (get-stride self)) (get-offset self) (get-stride self)))
(define-method (subst (self <lookup>) alist)
  (lookup (get-value self) (subst (get-var self) alist) (get-stride self)))
;(define-method (skip (self <lookup>) (var <var>) (amount <integer>))
;  (if (equal? var (get-var self))

(define-method (typecode (self <lookup>))
  (typecode (get-value self)))
