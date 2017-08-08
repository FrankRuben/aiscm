(use-modules (oop goops) (aiscm v4l2) (aiscm xorg))
(define v (make <v4l2>))
(define d (make <xdisplay> #:name ":0.0"))
(define w (make <xwindow> #:display d #:shape '(640 480) #:io IO-XVIDEO))
(title= w "Test")
(define (wait)
  (while (not (quit? d)) (write-image (read-image v) w) (process-events d))
  (quit= d #f))
(show w)
(wait)
(move w 40 20)
(wait)
(resize w 320 240)
(wait)
(move-resize w 60 30 480 360)
(wait)
(hide w)
(show-fullscreen w)
(wait)
(hide w)
(destroy d)
(destroy v)
