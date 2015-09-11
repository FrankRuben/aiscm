(define-module (aiscm image)
  #:use-module (oop goops)
  #:use-module (srfi srfi-26)
  #:use-module (ice-9 optargs)
  #:use-module (system foreign)
  #:use-module (aiscm mem)
  #:use-module (aiscm element)
  #:use-module (aiscm int)
  #:use-module (aiscm rgb)
  #:use-module (aiscm sequence)
  #:use-module (aiscm util)
  #:use-module (aiscm jit)
  #:use-module (aiscm op)
  #:export (<image> <meta<image>>
            get-format get-mem convert to-image))
(load-extension "libguile-image" "init_image")
(define-class* <image> <object> <meta<image>> <class>
              (format #:init-keyword #:format #:getter get-format)
              (shape #:init-keyword #:shape #:getter shape)
              (offsets #:init-keyword #:offsets #:getter get-offsets)
              (pitches #:init-keyword #:pitches #:getter get-pitches)
              (mem #:init-keyword #:mem #:getter get-mem))
(define-method (initialize (self <image>) initargs)
  (let-keywords initargs #f (format shape offsets pitches mem)
    (let* [(pitches (or pitches (default-pitches format (car shape))))
           (offsets (or offsets (default-offsets format pitches (cadr shape))))]
      (next-method self (list #:format format
                              #:shape shape
                              #:offsets offsets
                              #:pitches pitches
                              #:mem mem)))))
(define formats
  (list (cons 'RGB  PIX_FMT_RGB24)
        (cons 'BGR  PIX_FMT_BGR24)
        (cons 'BGRA PIX_FMT_BGRA)
        (cons 'GRAY PIX_FMT_GRAY8)
        (cons 'I420 PIX_FMT_YUV420P)
        (cons 'YV12 PIX_FMT_YUV420P)
        (cons 'UYVY PIX_FMT_UYVY422)
        (cons 'YUY2 PIX_FMT_YUYV422)
        (cons 'MJPG 0)))
(define symbols (alist-invert formats))
(define (sym->fmt sym) (assq-ref formats sym))
(define (fmt->sym fmt) (assq-ref symbols fmt))
(define (image-size format pitches height)
  (case format
    ((RGB)  (* (car pitches) height))
    ((BGR)  (* (car pitches) height))
    ((BGRA) (* (car pitches) height))
    ((GRAY) (* (car pitches) height))
    ((I420) (+ (* (car pitches) height) (* 2 (cadr pitches) (ash (+ height 1) -1))))
    ((YV12) (+ (* (car pitches) height) (* 2 (cadr pitches) (ash (+ height 1) -1))))
    ((UYVY) (* (car pitches) height 2))
    ((YUY2) (* (car pitches) height 2))
    ((MJPG) (* (car pitches) height 2))))
(define (default-offsets format pitches height)
  (case format
    ((RGB)  (list 0))
    ((BGR)  (list 0))
    ((BGRA) (list 0))
    ((GRAY) (list 0))
    ((I420) (list 0
                  (* (car pitches) height)
                  (+ (* (car pitches) height) (* (cadr pitches) (ash (+ height 1) -1)))))
    ((YV12) (list 0
                  (* (car pitches) height)
                  (+ (* (car pitches) height) (* (cadr pitches) (ash (+ height 1) -1)))))
    ((UYVY) (list 0))
    ((YUY2) (list 0))
    ((MJPG) (list 0))))
(define (default-pitches format width)
  (case format
    ((RGB)  (list (* width 3)))
    ((BGR)  (list (* width 3)))
    ((BGRA) (list (* width 4)))
    ((GRAY) (list width))
    ((I420) (list width (ash (+ width 1) -1) (ash (+ width 1) -1)))
    ((YV12) (list width (ash (+ width 1) -1) (ash (+ width 1) -1)))
    ((UYVY) (list (* 2 (logand (+ width 3) (lognot #x3)))))
    ((YUY2) (list (* 2 (logand (+ width 3) (lognot #x3)))))
    ((MJPG) (list))))
(define (warp lst indices) (map (cut list-ref lst <>) indices))
(define-method (descriptor (format <symbol>) (shape <list>) (offsets <list>) (pitches <list>))
  (list (sym->fmt format)
        shape
        (if (eqv? format 'YV12) (warp offsets '(0 2 1)) offsets)
        (if (eqv? format 'YV12) (warp pitches '(0 2 1)) pitches)))
(define-method (descriptor (self <image>))
  (descriptor (get-format self)
              (shape self)
              (get-offsets self)
              (get-pitches self)))
(define (memalign size alignment)
  (let* [(offset        (1- alignment))
         (extended-size (+ size offset))
         (mem           (make <mem> #:size extended-size))
         (base          (get-memory mem))
         (memory        (make-pointer (logand (+ (pointer-address base) offset) (lognot offset))))]
    (make <mem> #:memory memory #:base base #:size size)))
(define-method (convert (self <image>)
                        (fmt <symbol>)
                        (shape <list>)
                        (offsets <list>)
                        (pitches <list>))
  (let [(source-type (descriptor self))
        (dest-type   (descriptor fmt shape offsets pitches))]
    (if (equal? source-type dest-type)
      self
      (if (eq? (get-format self) 'MJPG)
        (if (and (eqv? (sym->fmt fmt) PIX_FMT_YUV420P)
                 (equal? (slot-ref self 'shape) shape)
                 (equal? pitches (default-pitches fmt (car shape))))
          (let* [(source-mem      (get-mem self))
                 (size            (image-size fmt pitches (cadr shape)))
                 (dest-mem        (memalign size 16))]
            (mjpeg-to-yuv420p (get-memory source-mem)
                              (car shape)
                              (cadr shape)
                              (get-memory dest-mem)
                              (caddr dest-type))
            (make <image> #:format fmt #:shape shape #:mem dest-mem))
          (convert (convert self 'YV12) fmt shape offsets pitches))
        (let* [(source-mem (get-mem self))
               (size       (image-size fmt pitches (cadr shape)))
               (dest-mem   (memalign size 16))]
          (image-convert (get-memory source-mem) source-type (get-memory dest-mem) dest-type)
          (make <image> #:format  fmt
                        #:shape   shape
                        #:mem     dest-mem
                        #:offsets offsets
                        #:pitches pitches))))))
(define-method (convert (self <image>) (format <symbol>) (shape <list>))
  (let* [(pitches (default-pitches format (car shape)))
         (offsets (default-offsets format pitches (cadr shape)))]
    (convert self format shape offsets pitches)))
(define-method (convert (self <image>) (format <symbol>))
  (convert self format (shape self)))
(define-method (write (self <image>) port)
  (format port "#<<image> ~a ~a>" (get-format self) (shape self)))
(define-method (to-array (self <image>))
  (case (get-format self)
    ((GRAY) (let* [(shape   (shape self))
                   (pitches (get-pitches self))
                   (size    (image-size 'GRAY pitches (cadr shape)))
                   (mem     (get-mem self))]
              (make (multiarray <ubyte> 2) #:value mem #:shape shape #:strides (cons 1 pitches))))
    ((BGR)  (let* [(shape   (shape self))
                   (pitches (get-pitches self))
                   (size    (image-size 'BGR pitches (cadr shape)))
                   (mem     (get-mem self))]
              (make (multiarray <ubytergb> 2) #:value mem #:shape shape #:strides (list 1 (/ (car pitches) 3)))))
    (else   (to-array (convert self 'BGR)))))
(define-method (to-image (self <image>)) self)
(define-method (to-image (self <sequence<>>))
  (cond ((equal? <ubyte> (typecode self))
         (if (= (car (strides self)) 1)
           (make <image> #:format 'GRAY
                         #:shape (shape self)
                         #:mem (get-value self)
                         #:offsets '(0)
                         #:pitches (list (cadr (strides self))))
           (to-image (duplicate self))))
        ((is-a? (typecode self) <meta<int<>>>)
         (to-image (to-type <ubyte> self)))
        ((equal? <ubytergb> (typecode self))
         (if (= (car (strides self)) 1)
           (make <image> #:format 'BGR
                         #:shape (shape self)
                         #:mem (get-value self)
                         #:offsets '(0)
                         #:pitches (list (* 3 (cadr (strides self)))))
           (to-image (duplicate self))))
        (else (next-method))))
