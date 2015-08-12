(use-modules (oop goops)
             (rnrs bytevectors)
             (srfi srfi-1)
             (srfi srfi-26)
             (aiscm util)
             (aiscm asm)
             (aiscm mem)
             (aiscm jit)
             (aiscm element)
             (aiscm int)
             (aiscm pointer)
             (aiscm sequence)
             (aiscm bool)
             (guile-tap))
(planned-tests 135)
(define ctx (make <context>))
(define b1 (random (ash 1  6)))
(define b2 (random (ash 1  6)))
(define w1 (random (ash 1 14)))
(define w2 (random (ash 1 14)))
(define i1 (random (ash 1 30)))
(define i2 (random (ash 1 30)))
(define l1 (random (ash 1 62)))
(define l2 (random (ash 1 62)))
(define mem (make <mem> #:size 256))
(define bptr (make (pointer <byte>) #:value mem))
(define wptr (make (pointer <sint>) #:value mem))
(define iptr (make (pointer <int>) #:value mem))
(define lptr (make (pointer <long>) #:value mem))
(define (bdata) (begin
                  (store bptr       b1)
                  (store (+ bptr 1) b2)
                  mem))
(define (wdata) (begin
                  (store wptr       w1)
                  (store (+ wptr 1) w2)
                  mem))
(define (idata) (begin
                  (store iptr       i1)
                  (store (+ iptr 1) i2)
                  mem))
(define (ldata) (begin
                  (store lptr       l1)
                  (store (+ lptr 1) l2)
                  mem))
(define a (make <var> #:type <int> #:symbol 'a))
(define b (make <var> #:type <int> #:symbol 'b))
(define c (make <var> #:type <int> #:symbol 'c))
(define u (make <var> #:type <ubyte> #:symbol 'u))
(define v (make <var> #:type <byte> #:symbol 'v))
(define w (make <var> #:type <sint> #:symbol 'w))
(define o (make <var> #:type <sint> #:symbol 'w))
(define p (make <var> #:type <long> #:symbol 'p))
(define q (make <var> #:type <long> #:symbol 'q))
(define x (make <var> #:type <long> #:symbol 'x))
(define y (make <var> #:type <long> #:symbol 'y))
(define z (make <var> #:type <long> #:symbol 'z))
(define *p (make (pointer <int>) #:value p))
(define *q (make (pointer <int>) #:value q))

(define s (param (sequence <int>) (list x y p)))
(define r (param (sequence <int>) (list x y q)))

(ok (equal? (list b) (input (MOV a b)))
    "Get input variables of MOV")
(ok (equal? (list a b) (input (ADD a b)))
    "Get input variables of ADD")
(ok (equal? (list a) (input (ADD a a)))
    "Prevent duplication of input variables")
(ok (equal? (list a) (output (MOV a b)))
    "Get output variables of MOV")
(ok (equal? (list a) (output (ADD a b)))
    "Get output variables of ADD")
(ok (equal? (list b a) (input (MOV (ptr <int> a) b)))
    "Get input variables of command writing to address")
(ok (equal? (list a 0) (get-args (MOV a 0)))
    "Get arguments of command")
(ok (equal? (list (MOV ECX 42))
            (let [(v (make <var> #:type <int> #:symbol 'v))]
              (substitute-variables (list (MOV v 42)) (list (cons v RCX)))))
    "Substitute integer variable with register")
(ok (equal? (list (MOV RCX (ptr <long> RAX)))
            (substitute-variables (list (MOV p (ptr <long> RAX))) (list (cons p RCX))))
    "Substitute long integer variable with register")
(ok (equal? (list (MOV (ptr <int> RCX) ESI))
            (substitute-variables (list (MOV (ptr <int> p) a)) (list (cons p RCX) (cons a RSI))))
    "Substitute pointer variable")
(ok (equal? (MOV EAX 0)
            (substitute-variables (substitute-variables (MOV a 0) (list (cons a b))) (list (cons b RAX))))
    "Substitute variable with another")
(ok (equal? (MOV ECX EDX) (substitute-variables (MOV a b) (list (cons a RCX) (cons b RDX))))
    "Substitution works with 'MOV'")
(ok (equal? (MOVSX RCX EDX) (substitute-variables (MOVSX p b) (list (cons p RCX) (cons b RDX))))
    "Substitution works with 'MOVSX'")
(ok (equal? (MOVZX ECX DX) (substitute-variables (MOVZX a w) (list (cons a RCX) (cons w RDX))))
    "Substitution works with 'MOVZX'")
(ok (equal? (LEA RCX (ptr <byte> RDX))
            (substitute-variables (LEA p (ptr <byte> q)) (list (cons p RCX) (cons q RDX))))
    "Substitution works with 'LEA")
(ok (equal? (SHL ECX) (substitute-variables (SHL a) (list (cons a RCX))))
    "Substitution works with 'SHL")
(ok (equal? (SHR ECX) (substitute-variables (SHR a) (list (cons a RCX))))
    "Substitution works with 'SHR")
(ok (equal? (SAL ECX) (substitute-variables (SAL a) (list (cons a RCX))))
    "Substitution works with 'SAL")
(ok (equal? (SAR ECX) (substitute-variables (SAR a) (list (cons a RCX))))
    "Substitution works with 'SAR")
(ok (equal? (ADD ECX EDX) (substitute-variables (ADD a b) (list (cons a RCX) (cons b RDX))))
    "Substitution works with 'ADD'")
(ok (equal? (PUSH ECX) (substitute-variables (PUSH a) (list (cons a RCX))))
    "Substitution works with 'PUSH'")
(ok (equal? (POP ECX) (substitute-variables (POP a) (list (cons a RCX))))
    "Substitution works with 'POP'")
(ok (equal? (NEG ECX) (substitute-variables (NEG a) (list (cons a RCX))))
    "Substitution works with 'NEG'")
(ok (equal? (SUB ECX EDX) (substitute-variables (SUB a b) (list (cons a RCX) (cons b RDX))))
    "Substitution works with 'SUB'")
(ok (equal? (IMUL ECX EDX) (substitute-variables (IMUL a b) (list (cons a RCX) (cons b RDX))))
    "Substitution works with 'IMUL'")
(ok (equal? (IMUL ECX EDX 2) (substitute-variables (IMUL a b 2) (list (cons a RCX) (cons b RDX))))
    "Substitution works with 'IMUL' and three arguments")
(ok (equal? (CMP ECX EDX) (substitute-variables (CMP a b) (list (cons a RCX) (cons b RDX))))
    "Substitution works with 'CMP'")
(ok (equal? (SETB CL) (substitute-variables (SETB u) (list (cons u RCX))))
    "Substitution works with 'SETB'")
(ok (equal?  (list a b) (variables (list (MOV a 0) (MOV b a))))
    "Get variables of a program")
(ok (equal? '((a . 1) (b . 3)) (labels (list (JMP 'a) 'a (MOV AX 0) 'b (RET))))
    "'labels' should extract indices of labels")
(ok (equal? '(1) (next-indices (MOV CX 0) 0 '()))
    "Get following indices for first statement in a program")
(ok (equal? '(2) (next-indices (MOV AX CX) 1 '()))
    "Get following indices for second statement in a program")
(ok (equal? '() (next-indices (RET) 2 '()))
    "RET statement should not have any following indices")
(ok (equal? '(2) (next-indices (JMP 'a) 0 '((a . 2))))
    "Get following indices for a jump statement")
(ok (equal? '(1 2) (next-indices (JNE 'a) 0 '((a . 2))))
    "Get following indices for a conditional jump")
(ok (equal? (list '() (list a) '()) (live-analysis (list 'x (MOV a 0) (RET))))
    "Live-analysis for definition of unused variable")
(ok (equal? (list (list a) (list a) (list b a) '()) (live-analysis (list (MOV a 0) (NOP) (MOV b a) (RET))))
    "Live-analysis for definition and later use of a variable")
(ok (equal? (list (list a) (list a) (list a) (list a) '())
            (live-analysis (list (MOV a 0) 'x (ADD a 1) (JE 'x) (RET))))
    "Live-analysis with conditional jump statement")
(ok (equal? (list (MOV EAX 42) (RET)) (register-allocate (list (MOV a 42) (RET))))
    "Allocate a single register")
(ok (equal? (list (MOV ECX 42) (RET))
            (register-allocate (list (MOV a 42) (RET)) #:registers (list RCX RDX)))
    "Allocate a single register using custom list of registers")
(ok (equal? (list (MOV ECX 1) (MOV EAX 2) (ADD ECX EAX) (MOV EAX ECX) (RET))
            (register-allocate (list (MOV a 1) (MOV b 2) (ADD a b) (MOV c a) (RET))))
    "Allocate multiple registers")
(ok (equal? (list (MOV ECX 1) (ADD ECX ESI) (MOV EAX ECX) (RET))
            (register-allocate (list (MOV b 1) (ADD b a) (MOV c b) (RET))
                               #:predefined (list (cons a RSI) (cons c RAX))))
    "Register allocation with predefined registers")
(ok (equal? (list (MOV EAX EDI) (ADD EAX ESI) (RET))
            (virtual-variables (list a) (list b c) (list (MOV a b) (ADD a c) (RET))))
    "'virtual-variables' uses the specified variables as parameters")
(ok (equal? (list (RET))
            (pass-parameter-variables <null> '() (lambda () (list (RET)))))
    "'pass-parameter-variables' handles empty function")
(ok (equal? (list (MOV (ptr <byte> RDI) 42) (RET))
            (pass-parameter-variables <null> (list <long>) (lambda (x) (list (MOV (ptr <byte> x) 42) (RET)))))
    "'pass-parameter-variables' allocates variables for function arguments")
(ok (equal? (list (MOV EAX 42) (RET))
            (pass-parameter-variables <int> '() (lambda (r) (list (MOV r 42) (RET)))))
    "'pass-parameter-variables' allocates variable for return value")
(ok (equal? (list (MOV AL DIL) (ADD AL 13) (RET))
            (pass-parameter-variables <byte> (list <byte>)
                                      (lambda (r a) (list (MOV r a) (ADD r 13) (RET)))))
    "'pass-parameter-variables' allocates variables for function arguments and return value")
(ok (equal? (list (MOV ECX 42) (MOV EAX ECX) (RET))
            (pass-parameter-variables <int> '() (lambda (r) (list (MOV a 42) (MOV r a) (RET)))))
    "'pass-parameter-variables' allocates local variables")
(ok (eq? 'new (get-target (retarget (JMP 'old) 'new)))
    "'retarget' should update target of jump statement")
(ok (equal? (list (JMP 1) 'a (NOP) (RET))
            (flatten-code (list (list (JMP 1) 'a) (NOP) (RET))))
    "'flatten-code' should flatten nested environments")
(ok (equal? (list (MOV EAX 0) (RET))
            (pass-parameter-variables <null> '() (lambda () (let [(v (make <var> #:type <int> #:symbol 'v))]
                                                              (list (list (MOV v 0)) (RET))))))
    "'pass-parameter-variables' handles nested code blocks")
(ok (equal? (list (MOV ECX (ptr <int> RSP 8)) (MOV EAX ECX) (RET))
            (pass-parameter-variables <int> (make-list 7 <int>)
                                      (lambda (r . args) (list (MOV r (list-ref args 6)) (RET)))))
    "'pass-parameter-variables' maps the 7th integer parameter correctly")
(ok (equal? (resolve-jumps (list (JMP 'b) (JMP 'a) 'a (NOP) 'b))
            (resolve-jumps (flatten-code (relabel (list (JMP 'a) (list (JMP 'a) 'a) (NOP) 'a)))))
    "'relabel' should create separate namespaces for labels")
(ok (lset= eq? (list RBP R12) (callee-saved (list RAX RBP R10 R10 R12 R12)))
    "'callee-saved' should extract the set of callee-saved registers")
(ok (equal? (list (MOV (ptr <long> RSP #x-8) RBP) (MOV (ptr <long> RSP #x-10) R12))
            (save-registers (list RBP R12) #x-8))
    "'save-registers' should generate instructions for saving registers on the stack")
(ok (equal? (list (MOV (ptr <long> RSP #x-10) RBP) (MOV (ptr <long> RSP #x-18) R12))
            (save-registers (list RBP R12) #x-10))
    "'save-registers' should use the specified offset")
(ok (equal? (list (MOV RBP (ptr <long> RSP #x-8)) (MOV R12 (ptr <long> RSP #x-10)))
            (load-registers (list RBP R12) #x-8))
    "'load-registers' should generate instructions for saving registers on the stack")
(ok (equal? (list (MOV RBP (ptr <long> RSP #x-10)) (MOV R12 (ptr <long> RSP #x-18)))
            (load-registers (list RBP R12) #x-10))
    "'load-registers' should use the specified offset")
(ok (equal? (list (MOV (ptr <long> RSP #x-8) R12) (MOV R12D 0) (MOV R12 (ptr <long> RSP #x-8)) (RET))
            (save-and-use-registers (list (MOV a 0) (RET)) (list (cons a R12)) '() -8))
    "'save-and-use-registers' should save and restore callee-saved registers")
(ok (equal? (list (MOV (ptr <long> RSP #x-10) R12) (MOV R12D 0) (MOV R12 (ptr <long> RSP #x-10)) (RET))
            (save-and-use-registers (list (MOV a 0) (RET)) (list (cons a R12)) '() -16))
    "'save-and-use-registers' should use the specified offset for saving callee-saved registers")
(ok (let [(b (make <var> #:type <int> #:symbol 'b))
          (i (make <var> #:type <ubyte> #:symbol 'i))]
      (equal? (list i b) (collate (list <int> <bool>) (list i b))))
    "'collate' passes through integer- and boolean-variables")
(ok (let* [(p (make <var> #:type <long> #:symbol 'p))
           (l (make <var> #:type <long> #:symbol 'l))
           (i (make <var> #:type <long> #:symbol 'i))
           (s (car (collate (list (sequence <byte>)) (list l i p))))]
      (equal? (list p l i) (list (get-value s) (car (shape s)) (car (strides s)))))
    "'collate' constructs sequences")
(ok (unspecified? ((translate ctx <null> '() (lambda () (list (RET))))))
    "'translate' can create an empty function")
(ok (eqv? i1 ((translate ctx <int> '() (lambda (r) (list (MOV r i1) (RET))))))
    "'translate' creates constant function returning an integer")
(ok (eqv? 5 ((translate ctx <ubyte> (list <ubyte> <ubyte>)
                      (lambda (sum x y) (list (MOV sum x) (ADD sum y) (RET)))) 2 3))
    "'translate' creates variables for integer parameters and return values")
(ok (equal? '(2 3 5 7 11 13)
            (map (lambda (i) (apply (translate ctx <int> (make-list 6 <int>)
                                          (lambda (r . args)
                                                  (list (MOV r (list-ref args i)) (RET))))
                   '(2 3 5 7 11 13))) (iota 6)))
    "'translate' maps the first 6 integer parameters correctly")
(ok (eqv? 5 ((translate ctx <long> (list (sequence <ubyte>))
                   (lambda (r s) (list (MOV r (car (shape s))) (RET))))
             (make (sequence <ubyte>) #:size 5)))
    "'translate' composes variables for representing sequences")
(ok (eqv? i1 ((translate ctx <int> (list (pointer <int>)) (lambda (r p) (list (MOV r (ptr <int> p)) (RET))))
              (make (pointer <int>) #:value (idata))))
    "'translate' handles pointer arguments")
(ok (equal?
      '(0 2 3)
      (let [(s (seq 1 2 3))]
        ((translate ctx <null> (list (sequence <ubyte>))
           (lambda (s) (list (MOV (ptr <ubyte> (get-value s)) 0) (RET)))) s)
        (to-list s)))
  "'translate' passes pointer variables for sequence data")
(ok (eqv? 3 ((translate ctx <int> '()  (lambda (r)
                                    (list (MOV r 0) (JMP 'a) (list 'a (MOV r 2)) 'a (ADD r 3) (RET))))))
    "'translate' creates separate namespaces for labels")
(ok (equal? (list (MOV EAX 42) 'x (RET))
            (flatten-code (spill-variable a (ptr <int> RSP -8) (list (MOV EAX 42) 'x (RET)))))
    "Variable spilling ignores machine code and labels")
(ok (equal? (list (MOV EAX 0) (MOV (ptr <int> RSP -8) EAX) (RET))
            (pass-parameter-variables <null> '() (lambda () (spill-variable a (ptr <int> RSP -8) (list (MOV a 0) (RET))))))
    "Write spilled variable to stack")
(ok (equal? (list (MOV EAX (ptr <int> RSP -16)) (MOV ECX EAX) (RET))
            (pass-parameter-variables <null> '() (lambda () (spill-variable a (ptr <int> RSP -16) (list (MOV ECX a) (RET))))))
    "Read spilled variable from stack")
(ok (equal? (list (MOV AL (ptr <byte> RSP -24)) (ADD AL 1) (MOV (ptr <byte> RSP -24) AL) (RET))
            (pass-parameter-variables <null> '() (lambda () (spill-variable u (ptr <byte> RSP -24) (list (ADD u 1) (RET))))))
    "Read and write spilled variable")
(ok (equal? (let [(prog (list (ADD a b) (ADD a c) (RET)))
                  (live (list (list a b c) (list a c) '()))]
              (map (idle-live prog live) (list a b c)))
            '(0 0 1))
    "Count times a variable is live but not used")
(ok (equal? (list (MOV EDI 1) (MOV ESI 2) (ADD ESI 3) (ADD EDI 4) (RET))
            (register-allocate (list (MOV a 1) (MOV b 2) (ADD b 3) (ADD a 4) (RET))
                               #:registers (list RSI RDI)))
    "'register-allocate' should use the specified set of registers")
(ok (equal? (list (MOV ESI 1)
                  (MOV (ptr <int> RSP -8) ESI)
                  (MOV ESI 2)
                  (ADD ESI 3)
                  (MOV ESI (ptr <int> RSP -8))
                  (ADD ESI 4)
                  (MOV (ptr <int> RSP -8) ESI)
                  (RET))
            (register-allocate (list (MOV a 1) (MOV b 2) (ADD b 3) (ADD a 4) (RET))
                               #:registers (list RSI)))
    "'register-allocate' should spill variables")
(ok (equal? (list (MOV ESI 1)
                  (MOV (ptr <int> RSP -8) ESI)
                  (MOV ESI 2)
                  (MOV (ptr <int> RSP -16) ESI)
                  (MOV ESI 3)
                  (ADD ESI 4)
                  (MOV ESI (ptr <int> RSP -16))
                  (ADD ESI 5)
                  (MOV (ptr <int> RSP -16) ESI)
                  (MOV ESI (ptr <int> RSP -8))
                  (ADD ESI 6)
                  (MOV (ptr <int> RSP -8) ESI)
                  (RET))
            (register-allocate (list (MOV a 1) (MOV b 2) (MOV c 3) (ADD c 4) (ADD b 5) (ADD a 6) (RET))
                               #:registers (list RSI)))
    "'register-allocate' should assign separate stack locations")
(ok (equal? (list (MOV (ptr <long> RSP -16) RBX)
                  (MOV EBX 1)
                  (MOV (ptr <int> RSP -8) EBX)
                  (MOV EBX 2)
                  (ADD EBX 3)
                  (MOV EBX (ptr <int> RSP -8))
                  (ADD EBX 4)
                  (MOV (ptr <int> RSP -8) EBX)
                  (MOV RBX (ptr <long> RSP -16))
                  (RET))
            (register-allocate (list (MOV a 1) (MOV b 2) (ADD b 3) (ADD a 4) (RET))
                               #:registers (list RBX)))
    "'register-allocate' should save callee-saved registers")
(ok (equal? '() ((spill-parameters (list a)) (list (cons a RDI))))
    "Register-parameter does not need spilling if a register is available for it")
(ok (equal? (list (MOV (ptr <int> RSP -16) EDI))
            ((spill-parameters (list a)) (list (cons a (ptr <int> RSP -16)))))
    "Write spilled parameter to the stack")
(ok (equal? '() ((fetch-parameters (list c)) (list (cons c (ptr <int> RSP +8)))))
    "Stack-parameter does not need loading if it is spilled")
(ok (equal? (list (MOV R10D (ptr <int> RSP 8)))
            ((fetch-parameters (list c)) (list (cons c R10))))
    "Read prespilled parameters into register if a register is available for it")
(ok (equal? (list (MOV (ptr <int> RSP -8) ESI) (MOV ESI EDI) (MOV EDI (ptr <int> RSP -8)) (ADD ESI EDI) (RET))
            (pass-parameter-variables <null> (list <int> <int>) (lambda (a b) (list (MOV c a) (ADD c b) (RET)))
                                      #:registers (list RSI RDI)))
    "Spill register-parameter to the stack")
(ok (equal? (list (ADD EDI 1) (MOV EDI (ptr <int> RSP 8)) (ADD EDI 2) (MOV (ptr <int> RSP 8) EDI) (RET))
            (pass-parameter-variables <null> (make-list 7 <int>)
                                      (lambda args (list (ADD (car args) 1) (ADD (last args) 2) (RET)))
                                      #:registers (list RDI)))
    "'pass-parameter-variables' maps the 7th integer parameter correctly")
(ok (equal? (list (MOV AX 0) (RET)) (env [] (MOV AX 0) (RET)))
    "'env' returns the function body as a list")
(ok (eq? 'x (slot-ref (car (env [(x <byte>)] x)) 'symbol))
    "'env' defines named variable objects")
(ok (eq? <byte> (slot-ref (car (env [(x <byte>)] x)) 'type))
    "'env' uses the specified types")
(ok (equal? (list (CMP EAX 0) (JE 7) (SUB EAX 1) (JMP -14))
            (resolve-jumps (until (CMP EAX 0) (SUB EAX 1))))
    "until loop")
(ok (equal? (apply + (iota 10))
            ((translate ctx <int> (list <int>)
                  (lambda (r x) (list (for [(i <int>) (MOV i 0) (CMP i x) (ADD i 1)] (ADD r i)) (RET)))) 10))
    "for loop")
(ok (equal? (list (MOV ECX 2) (RET)) (get-code (blocked AL (MOV ECX 2) (RET))))
    "'blocked' represents the specified code segment")
(ok (equal? RAX (get-reg (blocked RAX (MOV ECX 2) (RET))))
    "'blocked' stores the register to be blocked")
(ok (equal? (list (MOV ECX 2) (RET)) (filter-blocks (blocked RAX (MOV ECX 2) (RET))))
    "'filter-blocks' should remove blocked-register information")
(ok (equal? (list (MOV EDX 2) 'x (list (RET)))
            (filter-blocks (blocked RDX (MOV EDX 2) 'x (blocked RAX (RET)))))
    "'filter-blocks' should work recursively")
(ok (equal? (list (cons RAX '(0 . 1))) (blocked-intervals (blocked RAX (MOV EAX 0) (RET))))
    "'blocked-intervals' should extract the blocked intervals for each register")
(ok (equal? (list (cons RAX '(1 . 1))) (blocked-intervals (list (MOV EAX 0) (blocked RAX (RET)))))
    "Blocked intervals within a program should be offset correctly")
(ok (equal? (list (cons RAX '(2 . 2))) (blocked-intervals (list (list (MOV EAX 0) (NOP)) (blocked RAX (RET)))))
    "The offsets of 'blocked-intervals' should refer to the flattened code")
(ok (equal? (list (cons RAX '(1 . 4)) (cons RDX '(2 . 3)))
            (blocked-intervals (list 'x (blocked RAX (MOV AX 0) (blocked RDX (MOV DX 0) (IDIV CX)) (RET)))))
    "'blocked-intervals' should work recursively")
(ok (equal? (list (MOV AX 0) (RET))
            (pass-parameter-variables <null> '() (lambda () (list (blocked RCX (MOV w 0)) (RET)))))
    "'pass-parameter-variables' filters out the reserved-registers information")
(ok (equal? (list (MOV CX 0) (RET))
            (pass-parameter-variables <null> '() (lambda () (list (blocked RAX (MOV w 0)) (RET)))))
    "'pass-parameter-variables' avoids blocked registers when allocating variables")
(ok (equal? (list SIL AX R9D RDX) (list (reg 1 6) (reg 2 0) (reg 4 9) (reg 8 2)))
    "'reg' provides access to registers using register codes")
(ok (eq? <int> (type (fragment <int>)))
    "Type of code fragment")
(ok (eq? <fragment<int<>>> (super (fragment <int>)))
    "Super of code fragment wraps super of target type")
(ok (eq? <int> (type (class-of (parameter a))))
    "Check type of basic fragment wrapping variable")
(ok (eq? a (get-value (parameter a)))
    "Value of trivial expression is wrapped variable")
(ok (null? ((code (parameter a)) b))
    "The code for a trivial expression is empty")
(ok (equal? <sint> (type (class-of (typecast <sint> (parameter u)))))
    "Conversion to short integer returns a short integer")
(ok (equal? (list (MOV EAX EDI))
            (substitute-variables ((code (typecast <int> (parameter a))) b)
                                  (list (cons b RAX) (cons a RDI))))
    "Instantiate trivial type conversion using variable Substitution")
(ok (equal? (list (MOV EAX EDI) (RET))
            (assemble b (list a) (typecast <int> (parameter a))))
    "Trivial type conversion")
(ok (equal? (list (MOVZX EAX DIL) (RET))
            (assemble a (list u) (typecast <int> (parameter u))))
    "unsigned type conversion")
(ok (equal? (list (MOVSX EAX DIL) (RET))
            (assemble a (list v) (typecast <int> (parameter v))))
    "Signed type conversion")
(todo (equal? (list (MOV AL DIL) (RET))
            (assemble v (list a) (typecast <byte> (parameter a))))
    "Typecast integer to byte")
(ok (equal? 42 ((jit ctx (list <int>) (cut typecast <int> <>)) 42))
    "Run trivial type conversion")
(ok (eq? <int> (type (class-of (+ (parameter a) (parameter b)))))
    "Adding two integers returns an integer")
(ok (eq? <sint> (type (class-of (+ (parameter v) (parameter w)))))
    "Adding a byte and a short integer returns a short integer")
(ok (equal? (list (MOV EAX EDI) (MOV ECX ESI) (ADD EAX ECX) (RET))
            (assemble c (list a b) (+ (parameter a) (parameter b))))
    "Add two integers")
(ok (equal? (list (MOVSX EAX DIL) (MOV ECX ESI) (ADD EAX ECX) (RET))
            (assemble c (list v b) (+ (parameter v) (parameter b))))
    "Add byte and integer")
(ok (equal? (list (MOV EAX EDI) (MOVZX ECX SIL) (ADD EAX ECX) (RET))
            (assemble c (list a u) (+ (parameter a) (parameter u))))
    "Add integer and unsigned byte")
(ok (equal? 9 ((jit ctx (list <int> <int> <int>) +) 2 3 4))
    "Compiling a plus operation creates an equivalent machine program")
(ok (equal? (list (MOV AX DI) (MOVSX CX SIL) (ADD AX CX) (RET))
            (assemble o (list w v) (+ (parameter w) (parameter v))))
    "Adding a short integer and a byte does the required sign extension")
(ok (equal? 3 ((jit ctx (list <int> <sint> <ubyte>) +) 2 -3 4))
    "Compiling a plus operation with different types creates an equivalent machine program")
(ok (eq? (pointer <int>) (type (class-of (parameter *p))))
    "Check type of basic fragment wrapping pointer" )
(ok (eq? *p (get-value (parameter *p)))
    "Value of trivial expression is wrapped pointer")
(ok (null? ((code (parameter *p)) a))
    "The code for a trivial pointer expression is empty")
(ok (equal? (list (MOV EAX (ptr <int> EDI)) (RET))
            (assemble a (list *p) (fetch (parameter *p))))
    "Fetching data from a pointer")
(ok (equal? (list (MOV (ptr <int> EDI) ESI) (RET))
            (assemble '() (list *p a) (store (parameter *p) (parameter a))))
    "Store data at a pointer")
(ok (equal? a (compose-from <int> (list a)))
    "Compose integer from variables")
(ok (equal? (list a) (decompose a))
    "Decompose variable")
(ok (equal? (list p) (decompose *p))
    "Decompose pointer")
(ok (equal? p (get-value (compose-from (pointer <int>) (list p))))
    "Compose pointer from variables")
(ok (equal? i1 ((jit ctx (list (pointer <int>)) fetch)
                (make (pointer <int>) #:value (idata))))
    "Compile and run code for fetching data from a pointer")
(ok (equal? 42 (begin
                 ((jit ctx (list (pointer <int>) <int>) store)
                                (make (pointer <int>) #:value (idata)) 42)
                 (get-value (fetch iptr))))
    "Compile and run code for storing data at a pointer location")
(ok (equal? p (get-value (compose-from (sequence <int>) (list x y p))))
    "Pointer of sequence composed from variables")
(ok (equal? (list x) (shape (compose-from (sequence <int>) (list x y p))))
    "Shape of sequence composed from variables")
(ok (equal? (list y) (strides (compose-from (sequence <int>) (list x y p))))
    "Strides of sequence composed from variables")
