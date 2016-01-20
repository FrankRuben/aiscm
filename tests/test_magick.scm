(use-modules (aiscm magick)
             (aiscm element)
             (aiscm pointer)
             (aiscm sequence)
             (aiscm image)
             (aiscm rgb)
             (guile-tap))
(planned-tests 3)
(define img (read-image "fixtures/ramp.png"))
(ok (equal? '(6 4) (shape img))
    "Check size of loaded image")
(ok (equal? (rgb 2 1 128) (get (to-array img) 2 1))
    "Check loaded image")
(ok (throws? (read-image "fixtures/nonexistent.png"))
    "Throw exception if file not found")
