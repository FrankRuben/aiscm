(use-modules (aiscm magick) (aiscm xorg) (aiscm image) (aiscm core))
(define (to-gray arr) (to-array (convert-image (to-image arr) 'GRAY)))
(show (to-gray (read-image "fubk.png")))
