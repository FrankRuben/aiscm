(use-modules (aiscm core))
(define c (arr 2+3i 5+7i))
c
;#<multiarray<complex<float<double>>,1>>:
;(2.0+3.0i 5.0+7.0i)
(real-part c)
;#<multiarray<float<double>,1>>:
;(2.0 5.0)
(imag-part c)
;#<multiarray<float<double>,1>>:
;(3.0 7.0)
(complex (arr 2 5) (arr 3 7))
;#<multiarray<complex<float<double>>,1>>:
;(2.0+3.0i 5.0+7.0i)
(conj c)
;#<multiarray<complex<float<double>>,1>>:
;(2.0-3.0i 5.0-7.0i)
