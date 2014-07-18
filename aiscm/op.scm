(define-module (aiscm op)
  #:use-module (oop goops)
  #:use-module (system foreign)
  #:use-module (aiscm util)
  #:use-module (aiscm jit)
  #:use-module (aiscm mem)
  #:use-module (aiscm element)
  #:use-module (aiscm int)
  #:use-module (aiscm sequence)
  #:export (fill)
  #:re-export (+ -))
(define ctx (make <jit-context>))

(define-method (content (x <element>)) (get-value x))
(define-method (content (x <sequence<>>))
  (list ((compose pointer-address get-memory get-value) x)
        (car (shape x))
        (car (strides x))))

(define-method (+ (a <element>)) a)
(define-method (+ (a <element>) (b <element>))
  (let* [(ca   (class-of a))
         (cb   (class-of b))
         (cr   (coerce ca cb))
         (code (params ctx cr (list ca cb)
                       (lambda (pool a_ b_)
                         (env pool
                              [(r (reg cr pool))]
                              (MOV r a_)
                              (ADD r b_)))))
         (proc (lambda (a b) (make cr #:value (apply code (flatten (map content (list a b)))))))]
    (add-method! + (make <method> #:specializers (list ca cb) #:procedure proc))
    (+ a b)))
(define-method (+ (a <element>) (b <integer>))
  (+ a (make (match b) #:value b)))
(define-method (+ (a <integer>) (b <element>))
  (+ (make (match a) #:value a) b))
(define-method (+ (a <sequence<>>) (b <element>))
  (let* [(ca   (class-of a))
         (cb   (class-of b))
         (cr   (coerce ca cb))
         (ta   (typecode ca))
         (tr   (typecode cr))
         (code (params ctx <null> (list cr ca cb)
                       (lambda (pool r_ a_ b_)
                         (env pool
                              [(*r  (reg (get-value r_) pool))
                               (*a  (reg (get-value a_) pool))
                               (b   (reg b_ pool))
                               (r   (reg tr pool))
                               (n   (reg (car (shape r_)) pool))
                               (*rx (reg <long> pool))]
                              (LEA *rx (ptr tr *r n))
                              (CMP *r *rx)
                              (JE 'return)
                              'loop
                              ((if (eq? ta tr) MOV (if (signed? ta) MOVSX MOVZX)) r (ptr ta *a))
                              (ADD r b)
                              (MOV (ptr tr *r) r)
                              (ADD *r (size-of tr))
                              (ADD *a (size-of ta))
                              (CMP *rx *r)
                              (JNE 'loop)
                              'return))))
         (proc (lambda (a b)
                 (let [(r (make cr #:size (size a)))]
                   (apply code (flatten (map content (list r a b))))
                   r)))]
    (add-method! + (make <method> #:specializers (list ca cb) #:procedure proc))
    (+ a b)))
(define-method (+ (a <element>) (b <sequence<>>))
  (let* [(ca   (class-of a))
         (cb   (class-of b))
         (cr   (coerce ca cb))
         (tb   (typecode cb))
         (tr   (typecode cr))
         (code (params ctx <null> (list cr ca cb)
                       (lambda (pool r_ a_ b_)
                         (env pool
                              [(*r  (reg (get-value r_) pool))
                               (a   (reg a_ pool))
                               (*b  (reg (get-value b_) pool))
                               (r   (reg tr pool))
                               (w   (reg tr pool))
                               (n   (reg (car (shape r_)) pool))
                               (*rx (reg <long> pool))]
                              (LEA *rx (ptr tr *r n))
                              (CMP *r *rx)
                              (JE 'return)
                              'loop
                              (MOV r a)
                              ((if (eq? tb tr) MOV (if (signed? tb) MOVSX MOVZX)) w (ptr tb *b))
                              (ADD r w)
                              (MOV (ptr tr *r) r)
                              (ADD *r (size-of tr))
                              (ADD *b (size-of tb))
                              (CMP *rx *r)
                              (JNE 'loop)
                              'return))))
         (proc (lambda (a b)
                 (let [(r (make cr #:size (size b)))]
                   (apply code (flatten (map content (list r a b))))
                   r)))]
    (add-method! + (make <method> #:specializers (list ca cb) #:procedure proc))
    (+ a b)))
(define-method (+ (a <sequence<>>) (b <sequence<>>))
  (let* [(ca   (class-of a))
         (cb   (class-of b))
         (cr   (coerce ca cb))
         (ta   (typecode ca))
         (tb   (typecode cb))
         (tr   (typecode cr))
         (code (params ctx <null> (list cr ca cb)
                       (lambda (pool r_ a_ b_)
                         (env pool
                              [(*r  (reg (get-value r_) pool))
                               (*a  (reg (get-value a_) pool))
                               (*b  (reg (get-value b_) pool))
                               (r   (reg tr pool))
                               (w   (reg tr pool))
                               (n   (reg (car (shape r_)) pool))
                               (*rx (reg <long> pool))]
                              (LEA *rx (ptr tr *r n))
                              (CMP *r *rx)
                              (JE 'return)
                              'loop
                              ((if (eq? ta tr) MOV (if (signed? ta) MOVSX MOVZX)) r (ptr ta *a))
                              (if (eq? tb tr)
                                (ADD r (ptr tb *b))
                                (append
                                  ((if (signed? tb) MOVSX MOVZX) w (ptr tb *b))
                                  (ADD r w)))
                              (MOV (ptr tr *r) r)
                              (ADD *r (size-of tr))
                              (ADD *a (size-of ta))
                              (ADD *b (size-of tb))
                              (CMP *rx *r)
                              (JNE 'loop)
                              'return))))
         (proc (lambda (a b)
                 (let [(r (make cr #:size (size a)))]
                   (apply code (flatten (map content (list r a b))))
                   r)))]
    (add-method! + (make <method> #:specializers (list ca cb) #:procedure proc))
    (+ a b)))

(define-method (- (a <element>))
  (let* [(ca   (class-of a))
         (cr   ca)
         (code (params ctx cr (list ca)
                       (lambda (pool a_)
                         (env pool
                              [(r (reg cr pool))]
                              (MOV r a_)
                              (NEG r)))))
         (proc (lambda (a) (make cr #:value (apply code (flatten (map content (list a)))))))]
    (add-method! - (make <method> #:specializers (list ca) #:procedure proc))
    (- a)))
(define-method (- (a <sequence<>>))
  (let* [(ca   (class-of a))
         (ta   (typecode ca))
         (cr   ca)
         (tr   (typecode cr))
         (code (params ctx <null> (list cr ca)
                       (lambda (pool r_ a_)
                         (env pool
                              [(*r  (reg (get-value r_) pool))
                               (*a  (reg (get-value a_) pool))
                               (r   (reg tr pool))
                               (n   (reg (car (shape r_)) pool))
                               (*rx (reg <long> pool))]
                              (LEA *rx (ptr tr *r n))
                              (CMP *r *rx)
                              (JE 'return)
                              'loop
                              (MOV r (ptr ta *a))
                              (NEG r)
                              (MOV (ptr tr *r) r)
                              (ADD *r (size-of tr))
                              (ADD *a (size-of ta))
                              (CMP *rx *r)
                              (JNE 'loop)
                              'return))))
         (proc (lambda (a)
                 (let [(r (make cr #:size (size a)))]
                   (apply code (flatten (map content (list r a))))
                   r)))]
    (add-method! - (make <method> #:specializers (list ca) #:procedure proc))
    (- a)))
(define-method (- (a <element>) (b <element>))
  (let* [(ca   (class-of a))
         (cb   (class-of b))
         (cr   (coerce ca cb))
         (code (params ctx cr (list ca cb)
                       (lambda (pool a_ b_)
                         (env pool
                              [(r (reg cr pool))]
                              (MOV r a_)
                              (SUB r b_)))))
         (proc (lambda (a b) (make cr #:value (apply code (flatten (map content (list a b)))))))]
    (add-method! - (make <method> #:specializers (list ca cb) #:procedure proc))
    (- a b)))
(define-method (- (a <element>) (b <integer>))
  (- a (make (match b) #:value b)))
(define-method (- (a <integer>) (b <element>))
  (- (make (match a) #:value a) b))
(define-method (- (a <sequence<>>) (b <element>))
  (let* [(ca   (class-of a))
         (cb   (class-of b))
         (cr   (coerce ca cb))
         (ta   (typecode ca))
         (tr   (typecode cr))
         (code (params ctx <null> (list cr ca cb)
                       (lambda (pool r_ a_ b_)
                         (env pool
                              [(*r  (reg (get-value r_) pool))
                               (*a  (reg (get-value a_) pool))
                               (b   (reg b_ pool))
                               (r   (reg tr pool))
                               (n   (reg (car (shape r_)) pool))
                               (*rx (reg <long> pool))]
                              (LEA *rx (ptr tr *r n))
                              (CMP *r *rx)
                              (JE 'return)
                              'loop
                              ((if (eq? ta tr) MOV (if (signed? ta) MOVSX MOVZX)) r (ptr ta *a))
                              (SUB r b)
                              (MOV (ptr tr *r) r)
                              (ADD *r (size-of tr))
                              (ADD *a (size-of ta))
                              (CMP *rx *r)
                              (JNE 'loop)
                              'return))))
         (proc (lambda (a b)
                 (let [(r (make cr #:size (size a)))]
                   (apply code (flatten (map content (list r a b))))
                   r)))]
    (add-method! - (make <method> #:specializers (list ca cb) #:procedure proc))
    (- a b)))
(define-method (- (a <element>) (b <sequence<>>))
  (let* [(ca   (class-of a))
         (cb   (class-of b))
         (cr   (coerce ca cb))
         (tb   (typecode cb))
         (tr   (typecode cr))
         (code (params ctx <null> (list cr ca cb)
                       (lambda (pool r_ a_ b_)
                         (env pool
                              [(*r  (reg (get-value r_) pool))
                               (a   (reg a_ pool))
                               (*b  (reg (get-value b_) pool))
                               (r   (reg tr pool))
                               (w   (reg tr pool))
                               (n   (reg (car (shape r_)) pool))
                               (*rx (reg <long> pool))]
                              (LEA *rx (ptr tr *r n))
                              (CMP *r *rx)
                              (JE 'return)
                              'loop
                              (MOV r a)
                              (if (eq? tb tr)
                                (SUB r (ptr tb *b))
                                (append
                                  ((if (signed? tb) MOVSX MOVZX) w (ptr tb *b))
                                  (SUB r w)))
                              (MOV (ptr tr *r) r)
                              (ADD *r (size-of tr))
                              (ADD *b (size-of tb))
                              (CMP *rx *r)
                              (JNE 'loop)
                              'return))))
         (proc (lambda (a b)
                 (let [(r (make cr #:size (size b)))]
                   (apply code (flatten (map content (list r a b))))
                   r)))]
    (add-method! - (make <method> #:specializers (list ca cb) #:procedure proc))
    (- a b)))
(define-method (- (a <sequence<>>) (b <sequence<>>))
  (let* [(ca   (class-of a))
         (cb   (class-of b))
         (cr   (coerce ca cb))
         (ta   (typecode ca))
         (tb   (typecode cb))
         (tr   (typecode cr))
         (code (params ctx <null> (list cr ca cb)
                       (lambda (pool r_ a_ b_)
                         (env pool
                              [(*r  (reg (get-value r_) pool))
                               (*a  (reg (get-value a_) pool))
                               (*b  (reg (get-value b_) pool))
                               (r   (reg tr pool))
                               (w   (reg tr pool))
                               (n   (reg (car (shape r_)) pool))
                               (*rx (reg <long> pool))]
                              (LEA *rx (ptr tr *r n))
                              (CMP *r *rx)
                              (JE 'return)
                              'loop
                              ((if (eq? ta tr) MOV (if (signed? ta) MOVSX MOVZX)) r (ptr ta *a))
                              (if (eq? tb tr)
                                (SUB r (ptr tb *b))
                                (append
                                  ((if (signed? tb) MOVSX MOVZX) w (ptr tb *b))
                                  (SUB r w)))
                              (MOV (ptr tr *r) r)
                              (ADD *r (size-of tr))
                              (ADD *a (size-of ta))
                              (ADD *b (size-of tb))
                              (CMP *rx *r)
                              (JNE 'loop)
                              'return))))
         (proc (lambda (a b)
                 (let [(r (make cr #:size (size a)))]
                   (apply code (flatten (map content (list r a b))))
                   r)))]
    (add-method! - (make <method> #:specializers (list ca cb) #:procedure proc))
    (- a b)))

(define-method (fill (t <meta<element>>) (n <integer>) value)
  (let* [(cr   (sequence t))
         (code (params ctx <null> (list cr t)
                       (lambda (pool r_ value_)
                         (env pool
                              [(*r    (reg (get-value r_) pool))
                               (value (reg value_ pool))
                               (n     (reg (car (shape r_)) pool))
                               (*rx   (reg <long> pool))]
                              (LEA *rx (ptr t *r n))
                              (CMP *r *rx)
                              (JE 'return)
                              'loop
                              (MOV (ptr t *r) value)
                              (ADD *r (size-of t))
                              (CMP *r *rx)
                              (JNE 'loop)
                              'return))))
         (proc (lambda (t n value)
                 (let [(r (make cr #:size n))]
                   (apply code (flatten (list (content r) value)))
                   r)))]
    (add-method! fill (make <method>
                            #:specializers (list (class-of t) <integer> (class-of value))
                            #:procedure proc))
    (fill t n value)))
