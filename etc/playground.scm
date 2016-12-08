(use-modules (oop goops)
             (srfi srfi-1)
             (srfi srfi-26)
             (system foreign)
             (aiscm element)
             (aiscm int)
             (aiscm sequence)
             (aiscm mem)
             (aiscm pointer)
             (aiscm rgb)
             (aiscm obj)
             (aiscm asm)
             (aiscm jit)
             (aiscm method)
             (aiscm util)
             (guile-tap))

(define default-registers (list RAX RCX RDX RSI RDI R10 R11 R9 R8 RBX R12 R13 R14 R15))

(define (unallocated-variables allocation)
   "Return a list of unallocated variables"
   (map car (filter (compose not cdr) allocation)))

(define (register-allocations allocation)
   "Return a list of variables with register allocated"
   (filter cdr allocation))

(define (assign-spill-locations variables offset increment)
  "Assign spill locations to a list of variables"
  (map (lambda (variable index) (cons variable (ptr (typecode variable) RSP index)))
       variables
       (iota (length variables) offset increment)))

(define (add-spill-information allocation offset increment)
  "Allocate spill locations for spilled variables"
  (append (register-allocations allocation)
          (assign-spill-locations (unallocated-variables allocation) offset increment)))

(define (linear-scan-coloring live-intervals registers predefined)
  "Linear scan register allocation based on live intervals"
  (define (linear-allocate live-intervals register-use variable-use result)
   (if (null? live-intervals)
        result
        (let* [(candidate    (car live-intervals))
               (variable     (car candidate))
               (interval     (cdr candidate))
               (first-index  (car interval))
               (last-index   (cdr interval))
               (variable-use (mark-used-till variable-use variable last-index))
               (register     (or (assq-ref predefined variable)
                                 (find-available register-use first-index)))
               (recursion    (lambda (result register)
                               (linear-allocate (cdr live-intervals)
                                                (mark-used-till register-use register last-index)
                                                variable-use
                                                (assq-set result variable register))))]
          (if register
            (recursion result register)
            (let* [(spill-candidate (longest-use variable-use))
                   (register        (assq-ref result spill-candidate))]
              (recursion (assq-set result spill-candidate #f) register))))))
  (linear-allocate (sort-live-intervals live-intervals (map car predefined))
                   (initial-register-use registers)
                   '()
                   '()))

(define* (linear-scan-allocate prog #:key (registers default-registers)
                                          (predefined '()))
  "Linear scan register allocation for a given program"
  (let* [(live         (live-analysis prog '())); TODO: specify return values here
         (all-vars     (variables prog))
         (intervals    (live-intervals live all-vars))
         (substitution (linear-scan-coloring intervals registers predefined))]
    (adjust-stack-pointer 8 (substitute-variables prog substitution))))

(let [(a (var <int>))
      (b (var <int>))
      (c (var <int>))
      (x (var <sint>))]
  (ok (equal? (list (SUB RSP 8) (MOV EAX 42) (ADD RSP 8) (RET))
              (linear-scan-allocate (list (MOV a 42) (RET))))
      "Allocate a single register")
  (ok (equal? (list (SUB RSP 8) (MOV ECX 42) (ADD RSP 8) (RET))
              (linear-scan-allocate (list (MOV a 42) (RET)) #:registers (list RCX RDX)))
      "Allocate a single register using custom list of registers")
  (ok (equal? (list (SUB RSP 8) (MOV EAX 1) (MOV ECX 2) (ADD EAX ECX) (MOV ECX EAX) (ADD RSP 8) (RET))
              (linear-scan-allocate (list (MOV a 1) (MOV b 2) (ADD a b) (MOV c a) (RET))))
      "Allocate multiple registers")
  (ok (equal? (list (SUB RSP 8) (MOV ECX 1) (ADD ECX ESI) (MOV EAX ECX) (ADD RSP 8) (RET))
              (linear-scan-allocate (list (MOV b 1) (ADD b a) (MOV c b) (RET))
                                 #:predefined (list (cons a RSI) (cons c RAX))))
      "Register allocation with predefined registers")
  (ok (equal? '() (unallocated-variables '()))
      "no variables means no unallocated variables")
  (ok (equal? (list a) (unallocated-variables (list (cons a #f))))
      "return the unallocated variable")
  (ok (equal? '() (unallocated-variables (list (cons a RAX))))
      "ignore the variable with register allocated")
  (ok (equal? '() (register-allocations '()))
      "no variables means no variables with register allocated")
  (ok (equal? (list (cons a RAX)) (register-allocations (list (cons a RAX))))
      "return the variable with register allocation information")
  (ok (equal? '() (register-allocations (list (cons a #f))))
      "filter out the variable which does not have a register allocated")
  (ok (equal? '()  (assign-spill-locations '() 16 8))
      "assigning spill locations to an empty list of variables returns an empty list")
  (ok (equal? (list (cons a (ptr <int> RSP 16)))  (assign-spill-locations (list a) 16 8))
      "assign spill location to a variable")
  (ok (equal? (list (cons a (ptr <int> RSP 32)))  (assign-spill-locations (list a) 32 8))
      "assign spill location with a different offset")
  (ok (equal? (list (cons x (ptr <sint> RSP 16)))  (assign-spill-locations (list x) 16 8))
      "use correct type for spill location")
  (ok (equal? (list (cons a (ptr <int> RSP 16)) (cons b (ptr <int> RSP 24)))
              (assign-spill-locations (list a b) 16 8))
      "use increasing offsets for spill locations")
  (ok (equal? '() (add-spill-information '() 16 8))
      "do nothing if there are no variables")
  (ok (equal? (list (cons a RAX)) (add-spill-information (list (cons a RAX)) 16 8))
      "pass through variables with register allocation information")
  (ok (equal? (list (cons a (ptr <int> RSP 16))) (add-spill-information (list (cons a #f)) 16 8))
      "allocate spill location for a variable"))

(run-tests)
