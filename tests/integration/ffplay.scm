(use-modules (oop goops) (aiscm ffmpeg) (aiscm xorg) (aiscm pulse) (aiscm util) (aiscm element) (aiscm image))
(define video (open-ffmpeg-input "av-sync.mp4"))
(define pulse (make <pulse-play> #:rate (rate video) #:channels (channels video) #:typecode (typecode video)))
(show
  (lambda (dsp)
    (while (< (audio-pts video) (+ (video-pts video) 0.2)) (write-samples (or (read-audio video) (break)) pulse))
    (format #t "video pts = ~8,2f, audio-pts = ~8,2f, latency = ~8,2f~&" (video-pts video) (audio-pts video) (latency pulse))
    (synchronise (read-video video) (- (video-pts video) (- (audio-pts video) (latency pulse))) (event-loop dsp))))
(drain pulse)
