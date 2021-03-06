(use-modules (oop goops) (aiscm core) (aiscm v4l2) (aiscm xorg) (aiscm opencv))
(define v (make <v4l2>))
(show
  (lambda _
    (let* [(img     (to-array (read-image v)))
           (markers (detect-markers img DICT_4X4_50))]
      (draw-detected-markers img markers))))
