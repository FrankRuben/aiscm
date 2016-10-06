(define-module (aiscm composite)
  #:use-module (oop goops) 
  #:use-module (aiscm util) 
  #:use-module (aiscm element)
  #:export (<composite> <meta<composite>>))
(define-class* <composite> <element> <meta<composite>> <meta<element>>)

(define-method (pointerless? (self <meta<composite>>)) (pointerless? (base self)))
