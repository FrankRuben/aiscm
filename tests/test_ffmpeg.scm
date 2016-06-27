(use-modules (aiscm ffmpeg)
             (aiscm element)
             (guile-tap))
(define video (open-input-video "fixtures/camera.avi"))
(ok (equal? '(6 4) (shape video))
    "Check frame size of input video")
(ok (throws? (open-input-video "fixtures/no-such-file.avi"))
    "Throw error if file does not exist")
(run-tests)
