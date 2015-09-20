(use-modules (oop goops)
             (rnrs bytevectors)
             (system foreign)
             (srfi srfi-1)
             (aiscm mem)
             (aiscm element)
             (aiscm pointer)
             (aiscm int)
             (aiscm rgb)
             (aiscm sequence)
             (aiscm image)
             (aiscm jit)
             (guile-tap))
(planned-tests 16)
(define l '((2 3 5 7) (11 13 17 19)))
(define c (list (list (rgb 2 3 5) (rgb 7 11 13)) (list (rgb 3 5 7) (rgb 5 7 11))))
(define m (to-array <ubyte> l))
(define mem (get-value m))
(define img (make <image> #:format 'GRAY #:shape '(8 1) #:mem mem))
(diagnostics "following test only works with recent version of libswscale")
(skip (equal? #vu8(2 2 2 3 3 3) (read-bytes (get-mem (convert img 'BGR)) 6))
  "conversion to BGR")
(ok (equal? '(16 2) (shape (convert img 'BGRA '(16 2))))
  "shape of scaled image")
(ok (eqv? (get-mem img) (get-mem (convert img 'GRAY)))
  "do nothing if converting to identical format")
(ok (equal? #vu8(2 3 5 7 11 13 17 19 2 3 5 7 11 13 17 19)
            (read-bytes (get-mem (convert img 'GRAY '(8 2))) 16))
  "values of image with scaled height")
(ok (equal? 2 (bytevector-u8-ref (read-bytes (get-mem (convert img 'GRAY '(8 2) '(0) '(16))) 32) 16))
  "correct application of custom pitches")
(ok (equal? '((2 3 5 7 11 13 17 19)) (to-list (to-array img)))
  "'to-array' should convert the image to a 2D array")
(diagnostics "following test only works with recent version of libswscale")
(skip (equal? (list (rgb 1 1 1) (rgb 2 2 2) (rgb 3 3 3)) (to-list (crop 3 (project (to-array (convert img 'UYVY))))))
  "'to-array' should convert the image to a colour image")
(ok (equal? '(2 2) (to-list (project (roll (to-array (convert img 'GRAY '(8  2) '(0) '(16)))))))
  "'to-array' should take pitches (strides) into account")
(ok (equal? 'GRAY (get-format (to-image m)))
  "'to-image' converts to grayscale image")
(ok (to-image img)
  "'to-image' for an image has no effect")
(ok (equal? '(4 2) (shape (to-image m)))
  "'to-image' preserves shape of array")
(ok (equal? l (to-list (to-array (to-image m))))
  "Converting from unsigned byte multiarray to image and back preserves data")
(ok (equal? #vu8(1 3 2 4) (read-bytes (get-mem (to-image (roll (arr (1 2) (3 4))))) 4))
  "Conversion to image ensures compacting of pixel lines")
(ok (equal? l (to-list (to-array (to-image (to-array <int> l)))))
  "Converting from integer multiarray to image and back converts to byte data")
(ok (equal? c (to-list (to-array (to-image (to-array c)))))
  "Convert RGB array to image")
(ok (equal? c (to-list (to-array (to-image (to-array <intrgb> c)))))
  "Convert integer RGB array to image")
