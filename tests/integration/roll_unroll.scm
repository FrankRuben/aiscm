(use-modules (aiscm core))
(define a (arr ((1 2 3) (4 5 6))))
a
;#<multiarray<int<8,unsigned>,3>>:
;((((1 2 3)
;   (4 5 6))))
(shape a)
;(1 2 3)
(unroll a)
;#<multiarray<int<8,unsigned>,3>>:
;(((1 4))
; ((2 5))
; ((3 6)))
(shape (unroll a))
;(3 1 2)
(roll a)
;#<multiarray<int<8,unsigned>,3>>:
;(((1)
;  (2)
;  (3))
; ((4)
;  (5)
;  (6)))
(shape (roll a))
;(2 3 1)
(get (unroll a) 0)
;#<multiarray<int<8,unsigned>,2>>:
;((1 4))
