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
             (aiscm rgb)
             (guile-tap))
(planned-tests 235)
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
(let [(a (var <int>))
      (b (var <int>))]
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
  (ok (equal?  (list a b) (variables (list (MOV a 0) (MOV b a))))
      "Get variables of a program")
  (let [(p (var <long>))]
    (ok (equal?  (list a p) (variables (list (MOV a 0) (MOV (ptr <int> p) a))))
        "Get variables of a program using a pointer"))
  (ok (equal? (list (MOV ECX 42)) (substitute-variables (list (MOV a 42)) (list (cons a RCX))))
      "Substitute integer variable with register")
  (ok (equal? (MOV EAX 0)
              (substitute-variables (substitute-variables (MOV a 0) (list (cons a b))) (list (cons b RAX))))
      "Substitute variable with another")
  (ok (equal? (MOV ECX EDX) (substitute-variables (MOV a b) (list (cons a RCX) (cons b RDX))))
      "Substitution works with 'MOV'")
  (let [(p (var <long>))]
    (ok (equal? (list (MOV RCX (ptr <long> RAX)))
                (substitute-variables (list (MOV p (ptr <long> RAX))) (list (cons p RCX))))
        "Substitute long integer variable with register")
    (ok (equal? (list (MOV (ptr <int> RCX) ESI))
                (substitute-variables (list (MOV (ptr <int> p) a)) (list (cons p RCX) (cons a RSI))))
        "Substitute pointer variable"))
  (let [(l (var <long>))
        (w (var <sint>))]
    (ok (equal? (MOVSX RCX EDX) (substitute-variables (MOVSX l a) (list (cons l RCX) (cons a RDX))))
        "Substitution works with 'MOVSX'")
    (ok (equal? (MOVZX ECX DX) (substitute-variables (MOVZX a w) (list (cons a RCX) (cons w RDX))))
        "Substitution works with 'MOVZX'"))
  (let [(p (var <long>))
        (q (var <long>))]
    (ok (equal? (LEA RCX (ptr <byte> RDX))
                (substitute-variables (LEA p (ptr <byte> q)) (list (cons p RCX) (cons q RDX))))
        "Substitution works with 'LEA"))
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
  (let [(u (var <ubyte>))]
    (ok (equal? (SETB CL) (substitute-variables (SETB u) (list (cons u RCX))))
        "Substitution works with 'SETB'"))
  (ok (equal? '((a . 1) (b . 3)) (labels (list (JMP 'a) 'a (MOV AX 0) 'b (RET))))
      "'labels' should extract indices of labels"))
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
(let [(a (var <int>))
      (b (var <int>))
      (c (var <int>))]
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
  (ok (equal? (list (MOV ECX EDI) (MOV EAX ECX) (RET))
              (virtual-variables (list a) (list b) (list (MOV c b) (MOV a c) (RET))))
      "'virtual-variables' allocates local variables"))
(ok (eq? 'new (get-target (retarget (JMP 'old) 'new)))
    "'retarget' should update target of jump statement")
(ok (equal? (list (JMP 1) 'a (NOP) (RET))
            (flatten-code (list (list (JMP 1) 'a) (NOP) (RET))))
    "'flatten-code' should flatten nested environments")
(let [(a (var <int>))
      (b (var <int>))]
  (ok (equal? (list (MOV EAX EDI) (RET))
              (virtual-variables (list a) (list b) (list (list (MOV a b)) (RET))))
      "'pass-parameter-variables' handles nested code blocks")
  (ok (equal? (list (MOV ECX (ptr <int> RSP 8)) (MOV EAX ECX) (RET))
              (let [(args (map var (make-list 7 <int>)))]
                 (virtual-variables (list a) args (list (MOV a (last args)) (RET)))))
      "'virtual-variables' maps the 7th integer parameter correctly"))
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
(let [(a (var <int>))]
  (ok (equal? (list (MOV (ptr <long> RSP #x-8) R12) (MOV R12D 0) (MOV R12 (ptr <long> RSP #x-8)) (RET))
              (save-and-use-registers (list (MOV a 0) (RET)) (list (cons a R12)) '() -8))
      "'save-and-use-registers' should save and restore callee-saved registers")
  (ok (equal? (list (MOV (ptr <long> RSP #x-10) R12) (MOV R12D 0) (MOV R12 (ptr <long> RSP #x-10)) (RET))
              (save-and-use-registers (list (MOV a 0) (RET)) (list (cons a R12)) '() -16))
      "'save-and-use-registers' should use the specified offset for saving callee-saved registers")
  (ok (eqv? 3 ((asm ctx <int> '()
                    (virtual-variables (list a) '()
                                       (list (MOV a 0) (JMP 'a) (list 'a (MOV a 2)) 'a (ADD a 3) (RET)))) ))
      "'virtual-variables' creates separate namespaces for labels")
  (ok (equal? (list (MOV EAX 42) 'x (RET))
              (flatten-code (spill-variable a (ptr <int> RSP -8) (list (MOV EAX 42) 'x (RET)))))
      "Variable spilling ignores machine code and labels")
  (ok (equal? (list (MOV EAX 0) (MOV (ptr <int> RSP -8) EAX) (RET))
              (register-allocate (flatten-code (spill-variable a (ptr <int> RSP -8) (list (MOV a 0) (RET))))))
      "Write spilled variable to stack")
  (ok (equal? (list (MOV EAX (ptr <int> RSP -16)) (MOV ECX EAX) (RET))
              (register-allocate (flatten-code (spill-variable a (ptr <int> RSP -16) (list (MOV ECX a) (RET))))))
      "Read spilled variable from stack"))
(let [(u (var <ubyte>))]
  (ok (equal? (list (MOV AL (ptr <byte> RSP -24)) (ADD AL 1) (MOV (ptr <byte> RSP -24) AL) (RET))
              (register-allocate (flatten-code (spill-variable u (ptr <int> RSP -24) (list (ADD u 1) (RET))))))
      "Read and write spilled variable"))
(let [(a (var <int>))
      (b (var <int>))]
  (let  [(p (var <long>))]
    (ok (equal? (let [(prog (list (ADD a b) (ADD a (ptr <int> p)) (RET)))
                      (live (list (list a b p) (list a p) '()))]
                  (map (idle-live prog live) (list a b p)))
                '(0 0 1))
        "Count times a variable is live but not used"))
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
  (let  [(c (var <int>))]
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
        "'register-allocate' should assign separate stack locations"))
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
      "'register-allocate' should save callee-saved registers"))
(let [(a (var <int>))]
  (ok (equal? '() ((spill-parameters (list a)) (list (cons a RDI))))
      "Register-parameter does not need spilling if a register is available for it")
  (ok (equal? (list (MOV (ptr <int> RSP -16) EDI))
              ((spill-parameters (list a)) (list (cons a (ptr <int> RSP -16)))))
      "Write spilled parameter to the stack")
  (ok (equal? '() ((fetch-parameters (list a)) (list (cons a (ptr <int> RSP +8)))))
      "Stack-parameter does not need loading if it is spilled")
  (ok (equal? (list (MOV R10D (ptr <int> RSP 8)))
              ((fetch-parameters (list a)) (list (cons a R10))))
      "Read prespilled parameters into register if a register is available for it")
  (let [(b (var <int>))
        (c (var <int>))]
    (ok (equal? (list (MOV (ptr <int> RSP -8) ESI) (MOV ESI EDI) (MOV EDI (ptr <int> RSP -8)) (ADD ESI EDI) (RET))
                (virtual-variables '() (list a b) (list (MOV c a) (ADD c b) (RET)) #:registers (list RSI RDI)))
        "Spill register-parameter to the stack")
    (ok (equal? (list (MOV EDX 0) (MOV ECX 0) (CMP ECX EAX) (JE #x6) (INC ECX) (INC EDX) (JMP #x-a) (RET))
                (resolve-jumps (register-allocate (flatten-code (list (MOV a 0) (repeat b (INC a)) (RET))))))
        "'repeat' loop")))
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
(let  [(w (var <usint>))]
  (ok (equal? (list (MOV AX 0) (RET))
              (virtual-variables '() '() (list (blocked RCX (MOV w 0)) (RET))))
      "'virtual-variables' filters out the reserved-registers information")
  (ok (equal? (list (MOV CX 0) (RET))
              (virtual-variables '() '() (list (blocked RAX (MOV w 0)) (RET))))
      "'virtual-variables' avoids blocked registers when allocating variables"))
(ok (equal? (list SIL AX R9D RDX) (list (reg 1 6) (reg 2 0) (reg 4 9) (reg 8 2)))
    "'reg' provides access to registers using register codes")
(ok (eq? <int> (type (fragment <int>)))
    "Type of code fragment")
(ok (eq? <fragment<int<>>> (super (fragment <int>)))
    "Super of code fragment wraps super of target type")
(ok (eq? <var> (class-of (var <int>)))
    "Shortcut for creating variables creates variables")
(ok (eq? <byte> (typecode (var <byte>)))
    "Shortcut for  creating variables uses specified type")
(ok (eq? <ubyte> (typecode (var <bool>)))
    "Boolean values are represented using unsigned byte")
(ok (eq? <byte> (typecode (red (var <bytergb>))))
    "Red channel of byte RGB variable is a byte variable")
(ok (eq? <byte> (typecode (green (var <bytergb>))))
    "Green channel of byte RGB variable is a byte variable")
(ok (eq? <byte> (typecode (blue (var <bytergb>))))
    "Blue channel of byte RGB variable is a byte variable")
(ok (eq? <int> (type (class-of (parameter (skeleton <int>)))))
    "Check type of basic fragment wrapping variable")
(ok (null? (code (parameter (skeleton <int>))))
    "The code for a trivial expression is empty")
(ok (equal? (MOV CL SIL) (mov-part CL ESI))
    "'mov-part' takes size of operation from first argument in 8-bit case")
(let [(a (var <int>))
      (b (var <int>))]
  (ok (equal? (mov-part ECX EDX) (substitute-variables (mov-part a b) (list (cons a RCX) (cons b RDX))))
      "Substitution works with 'mov-part'"))
(ok (eq? <int> (to-type <int> <byte>))
    "typecast for scalar type")
(ok (eq? <int> (typecode (to-type <int> (sequence <byte>))))
    "typecast element type to integer")
(ok (eq? 1 (dimension (to-type <int> (sequence <byte>))))
    "maintain dimension when typecasting")
(ok (equal? <sint> (type (class-of (to-type <sint> (parameter (skeleton <ubyte>))))))
    "Conversion to short integer returns a short integer")
(ok (equal? (list (MOVZX CX AL) (RET))
            (register-allocate (append (code (to-type <sint> (parameter (skeleton <ubyte>)))) (list (RET)))))
    "Type conversion instantiates corresponding code")
(ok (null? (code (to-type <int> (parameter (skeleton <int>)))))
    "Code for trivial type conversion is empty")
(let [(a (var <int>))
      (u (var <ubyte>))]
  (ok (equal? (list (MOV CL AL) (MOV EAX (ptr <int> RSP -8)) (SHL EAX CL) (MOV (ptr <int> RSP -8) EAX) (RET))
              (spill-blocked-predefines (list (MOV CL u) (SHL a CL) (RET))
                                        #:predefined (list (cons a RCX))
                                        #:blocked (list (cons RCX '(0 . 1)))))
      "Spill predefined registers if they are blocked"))
(let [(a (skeleton <int>))
      (b (skeleton <int>))
      (u (skeleton <ubyte>))
      (v (skeleton <byte>))]
  (ok (equal? (list (MOV EAX EDI) (RET))
              (assemble b (list a) (to-type <int> (parameter a))))
      "Trivial type conversion")
  (ok (equal? (list (MOVZX ECX DIL) (MOV EAX ECX) (RET))
              (assemble a (list u) (to-type <int> (parameter u))))
      "unsigned type conversion")
  (ok (equal? (list (MOVSX ECX DIL) (MOV EAX ECX) (RET))
              (assemble a (list v) (to-type <int> (parameter v))))
      "Signed type conversion")
  (ok (equal? (list (MOV CL DIL) (MOV AL CL) (RET))
              (assemble v (list a) (to-type <byte> (parameter a))))
      "Typecast integer to byte"))
(ok (equal? 42 ((jit ctx (list <int>) (cut to-type <int> <>)) 42))
    "Run trivial type conversion")
(ok (eq? <int> (type (class-of (+ (parameter (skeleton <int>)) (parameter (skeleton <int>))))))
    "Adding two integers returns an integer")
(ok (eq? <sint> (type (class-of (+ (parameter (skeleton <byte>)) (parameter (skeleton <sint>))))))
    "Adding a byte and a short integer returns a short integer")
(let [(a (skeleton <int>))
      (b (skeleton <int>))
      (c (skeleton <int>))
      (u (skeleton <ubyte>))
      (v (skeleton <byte>))]
  (ok (equal? (list (MOV ECX EDI) (MOV EAX ESI) (ADD ECX EAX) (MOV EAX ECX) (RET))
              (assemble c (list a b) (+ (parameter a) (parameter b))))
      "Add two integers")
  (ok (equal? (list (MOVSX EAX DIL) (MOV ECX EAX) (MOV EAX ESI) (ADD ECX EAX) (MOV EAX ECX) (RET))
              (assemble c (list v b) (+ (parameter v) (parameter b))))
      "Add byte and integer")
  (ok (equal? (list (MOVZX EAX SIL) (MOV ECX EDI) (MOV EDX EAX) (ADD ECX EDX) (MOV EAX ECX) (RET))
              (assemble c (list a u) (+ (parameter a) (parameter u))))
      "Add integer and unsigned byte"))
(ok (equal? 9 ((jit ctx (list <int> <int> <int>) +) 2 3 4))
    "Compiling a plus operation creates an equivalent machine program")
(let [(v (skeleton <byte>))
      (w (skeleton <sint>))
      (r (skeleton <sint>))]
  (ok (equal? (list (MOVSX AX SIL) (MOV CX DI) (MOV DX AX) (ADD CX DX) (MOV AX CX) (RET))
              (assemble r (list w v) (+ (parameter w) (parameter v))))
      "Adding a short integer and a byte does the required sign extension"))
(ok (equal? 3 ((jit ctx (list <int> <sint> <ubyte>) +) 2 -3 4))
    "Compiling a plus operation with different types creates an equivalent machine program")
(ok (eq? <int> (type (parameter (skeleton (pointer <int>)))))
    "Check type of basic fragment wrapping pointer" )
(let [(a (skeleton <int>))
      (p (skeleton (pointer <int>)))
      (q (skeleton (pointer <int>)))]
  (ok (equal? (list (MOV ECX (ptr <int> RDI)) (MOV EAX ECX) (RET))
              (assemble a (list p) (parameter p)))
      "Fetching data from a pointer")
  (ok (equal? (list (MOV (ptr <int> RDI) ESI) (RET))
              (assemble p (list a) (parameter a)))
      "Store data at a pointer")
  (ok (equal? (list (MOV EAX (ptr <int> ESI)) (MOV (ptr <int> EDI) EAX) (RET))
              (assemble p (list q) (parameter q)))
      "Copy data from pointer to pointer"))
(ok (eq? <intrgb> (class-of (skeleton <intrgb>)))
    "Skeleton of integer RGB has correct type")
(ok (eq? <rgb> (class-of (get (skeleton <intrgb>))))
    "Skeleton of integer RGB has RGB value")
(ok (equal? (make-list 3 <int>) (map typecode (content (get (skeleton <intrgb>)))))
    "Variables in integer RGB skeleton have correct type")
(ok (equal? (list <int>) (map typecode (decompose (skeleton <int>))))
    "Decompose integer")
(ok (equal? (list <long>) (map typecode (decompose (skeleton (pointer <int>)))))
    "Decompose pointer")
(ok (equal? (make-list 3 <int>) (map typecode (decompose (skeleton <intrgb>))))
    "Decompose RGB value")
(ok (eq? <var> (class-of (get (skeleton <int>))))
    "'skeleton' creates a variable for an integer type")
(ok (equal? <int> (class-of (skeleton <int>)))
    "'skeleton' creates a value of correct integer type")
(ok (equal? <int> (typecode (get (skeleton <int>))))
    "'skeleton' creates a variable of correct integer type")
(ok (eq? (sequence <int>) (class-of (skeleton (sequence <int>))) )
    "'skeleton' can create sequences")
(ok (eq? (pointer <int>) (class-of (skeleton (pointer <int>))))
    "Skeleton of pointer has correct type")
(ok (eq? <long> (typecode (get (skeleton (pointer <int>)))))
    "Skeleton of pointer is based on long integer")
(ok (equal? i1 ((jit ctx (list (pointer <int>)) identity)
                (make (pointer <int>) #:value (idata))))
    "Compile and run code for fetching data from a pointer")
(ok (equal? <long> (typecode (slot-ref (skeleton (sequence <byte>)) 'value)))
    "Pointer of sequence skeleton is a long integer")
(ok (equal? (list <long>) (map typecode (shape (skeleton (sequence <int>)))))
    "Shape of sequence is a list of long integers")
(ok (equal? (list <long>) (map typecode (strides (skeleton (sequence <int>)))))
    "Strides of sequence is a list of long integers")
(ok (equal? (make-list 3 <long>) (map typecode (decompose (skeleton (sequence <byte>)))))
    "Decomposing a sequence returns a list of 3 long integer variables")
(ok (equal? <long> (typecode (slot-ref (skeleton (multiarray <byte> 2)) 'value)))
    "Pointer of 2D array skeleton is a long integer")
(ok (equal? (list <long> <long>) (map typecode (shape (skeleton (multiarray <byte> 2)))))
    "Shape of 2D array skeleton is a list of long integers")
(ok (equal? (list <long> <long>) (map typecode (strides (skeleton (multiarray <byte> 2)))))
    "Strides of 2D array skeleton is a list of long integers")
(ok (equal? (make-list 5 <long>) (map typecode (decompose (skeleton (multiarray <byte> 2)))))
    "Decomposing a skeleton of a 2D array returns a list of 5 long integer variables")
(ok (equal? <int> (type (project (parameter (skeleton (sequence <int>))))))
    "A code fragment returning a sequence can be projected to an element")
(ok (is-a? ((jit ctx (list (sequence <int>)) identity) (seq <int> 1 2 3)) (sequence <int>))
    "Function returning sequence allocates return value")
(ok (equal? '(3) (shape ((jit ctx (list (sequence <int>)) identity) (seq <int> 1 2 3))))
    "Function returning sequence determines shape of result")
(ok (equal? '(1 2 3) (to-list ((jit ctx (list (sequence <int>)) identity) (seq <int> 1 2 3))))
    "Storing a sequence copies each element")
(ok (equal? -42 ((jit ctx (list <int>) -) 42))
    "Negate integer")
(ok (equal? '(253 252 250) (to-list ((jit ctx (list (sequence <ubyte>)) ~) (seq 2 3 5))))
    "Bitwise not of sequence")
(ok (equal? '(-1 2 -3) (to-list ((jit ctx (list (sequence <int>)) -) (seq <int> 1 -2 3))))
    "Negate sequence of integers")
(ok (equal? '(#f #f #t #f) (to-list ((jit ctx (list (sequence <int>)) =0) (seq <int> 1 -2 0 3))))
    "Element-wise comparison with zero")
(ok (equal? '(#t #t #f #t) (to-list ((jit ctx (list (sequence <int>)) !=0) (seq <int> 1 -2 0 3))))
    "Element-wise not-equal zero")
(ok (equal? '(-1 2 3) (to-list ((jit ctx (list (sequence <byte>)) (cut to-type <int> <>))
                                (seq <byte> -1 2 3))))
    "Typecasting a sequence should preserve values")
(ok (equal? '(0 1 2) (to-list ((jit ctx (list (sequence <int>) <byte>) +) (seq <int> 1 2 3) -1)))
    "Add byte to integer sequence")
(ok (equal? '(0 1 2) (to-list ((jit ctx (list <byte> (sequence <int>)) +) -1 (seq <int> 1 2 3))))
    "Add integer sequence to byte")
(ok (equal? '(0 6 1) (to-list ((jit ctx (list (sequence <int>) (sequence <int>)) +)
                               (seq <int> -2 3 -4) (seq <int> 2 3 5))))
    "Add two integer sequences")
(ok (equal? '(0 1 2) (to-list ((jit ctx (list (sequence <int>) <byte>) -) (seq <int> 1 2 3) 1)))
    "Subtract byte from integer sequence")
(ok (equal? '(2 4 6) (to-list ((jit ctx (list (sequence <int>) <int>) *) (seq <int> 1 2 3) 2)))
    "Multiply integer sequence with an integer")
(ok (equal? '(0 2 2) (to-list ((jit ctx (list (sequence <int>) <int>) &) (seq <int> 1 2 3) 2)))
    "Bitwise and of sequence and number")
(ok (equal? '(3 2 3) (to-list ((jit ctx (list (sequence <int>) <int>) |) (seq <int> 1 2 3) 2)))
    "Bitwise or of sequence and number")
(ok (equal? '(3 0 1) (to-list ((jit ctx (list (sequence <int>) <int>) ^) (seq <int> 1 2 3) 2)))
    "Bitwise xor of sequence and number")
(ok (equal? 12 ((jit ctx (list <int> <int>) <<) 3 2))
    "Compile program shifting 3 to the left by 2")
(ok (equal? '(4 8 12) (to-list ((jit ctx (list (sequence <int>) <ubyte>) <<) (seq <int> 1 2 3) 2) ) )
    "Shift-left sequence")
(ok (equal? '(8 4 2) (to-list ((jit ctx (list <int> (sequence <ubyte>)) >>) 16 (seq <ubyte> 1 2 3))))
    "Shift-right using sequence")
(ok (equal? '(#f #t #f) (to-list ((jit ctx (list (sequence <int>) <int>) =) (seq <int> 1 2 3) 2)))
    "Element-wise equal comparison")
(ok (equal? '(#t #f #t) (to-list ((jit ctx (list (sequence <int>) <int>) !=) (seq <int> 1 2 3) 2)))
    "Element-wise not-equal comparison")
(ok (equal? '(#f #f #f #t) (to-list ((jit ctx (list (sequence <bool>) (sequence <bool>)) &&)
                                     (seq #f #t #f #t) (seq #f #f #t #t))))
    "element-wise and")
(ok (equal? '(#f #t #t #t) (to-list ((jit ctx (list (sequence <bool>) (sequence <bool>)) ||)
                                     (seq #f #t #f #t) (seq #f #f #t #t))))
    "element-wise or")
(ok (equal? '(#t #f #f) (to-list ((jit ctx (list (sequence <ubyte>) <ubyte>) <) (seq 3 4 5) 4)))
    "element-wise lower-than")
(ok (equal? '(#t #t #f) (to-list ((jit ctx (list (sequence <ubyte>) <ubyte>) <=) (seq 3 4 5) 4)))
    "element-wise lower-equal")
(ok (equal? '(#f #f #t) (to-list ((jit ctx (list (sequence <ubyte>) <ubyte>) >) (seq 3 4 5) 4)))
    "element-wise greater-than")
(ok (equal? '(#f #t #t) (to-list ((jit ctx (list (sequence <ubyte>) <ubyte>) >=) (seq 3 4 5) 4)))
    "element-wise greater-equal")
(ok (equal? '(#t #f #f) (to-list ((jit ctx (list (sequence <byte>) <ubyte>) <) (seq -1 0 1) 0)))
    "element-wise lower-than of signed and unsigned bytes")
(ok (equal? '(#t #t #f) (to-list ((jit ctx (list (sequence <byte>) <ubyte>) <=) (seq -1 0 1) 0)))
    "element-wise lower-equal of signed and unsigned bytes")
(ok (equal? '(#f #f #t) (to-list ((jit ctx (list (sequence <byte>) <ubyte>) >) (seq -1 0 1) 0)))
    "element-wise greater-than of signed and unsigned bytes")
(ok (equal? '(#f #t #t) (to-list ((jit ctx (list (sequence <byte>) <ubyte>) >=) (seq -1 0 1) 0)))
    "element-wise greater-equal of signed and unsigned bytes")
(ok (equal? '(#f #f #f) (to-list ((jit ctx (list (sequence <ubyte>) <byte>) <) (seq 1 2 128) -1)))
    "element-wise lower-than of unsigned and signed bytes")
(ok (equal? '(#f #f #f) (to-list ((jit ctx (list (sequence <ubyte>) <byte>) <=) (seq 1 2 128) -1)))
    "element-wise lower-equal of unsigned and signed bytes")
(ok (equal? '(#t #t #t) (to-list ((jit ctx (list (sequence <ubyte>) <byte>) >) (seq 1 2 128) -1)))
    "element-wise greater-than of unsigned and signed bytes")
(ok (equal? '(#t #t #t) (to-list ((jit ctx (list (sequence <ubyte>) <byte>) >=) (seq 1 2 128) -1)))
    "element-wise greater-equal of unsigned and signed bytes")
(ok (equal? '(1 2 -3) (to-list ((jit ctx (list (sequence <byte>) <byte>) /) (seq 3 6 -9) 3)))
    "element-wise signed byte division")
(ok (equal? '(1200 -800 600) (to-list ((jit ctx (list <sint> (sequence <byte>)) /) 24000 (seq 20 -30 40))))
    "element-wise signed short integer division")
(ok (equal? '(120000 -80000) (to-list ((jit ctx (list <int> (sequence <byte>)) /) 2400000 (seq 20 -30))))
    "element-wise signed integer division")
(ok (equal? -1428571428 ((jit ctx (list <long> <ubyte>) /) -10000000000 7))
    "element-wise long integer division")
(ok (equal? '((1 2 3) (4 5 6))
            (to-list ((jit ctx (list (multiarray <ubyte> 2) <ubyte>) /) (arr (2 4 6) (8 10 12)) 2)))
    "element-wise division of two-dimensional array")
(ok (equal? '(127 126 125) (to-list ((jit ctx (list (sequence <ubyte>) <ubyte>) /) (seq 254 252 250) 2)))
    "element-wise unsigned byte division")
(ok (equal? '(1200 800 600) (to-list ((jit ctx (list <usint> (sequence <ubyte>)) /) 24000 (seq 20 30 40))))
    "element-wise unsigned short integer division")
(ok (equal? '(120000 80000 60000) (to-list ((jit ctx (list <uint> (sequence <ubyte>)) /) 2400000 (seq 20 30 40))))
    "element-wise unsigned integer division")
(ok (equal? 1428571428 ((jit ctx (list <ulong> <ubyte>) /) 10000000000 7))
    "unsigned long integer division")
(ok (equal? 33 ((jit ctx (list <ubyte> <ubyte>) %) 123 45))
    "unsigned byte remainder of division")
(ok (equal? 100 ((jit ctx (list <usint> <usint>) %) 1234 567))
    "unsigned short integer remainder of division")
(ok (equal? -30 ((jit ctx (list <byte> <byte>) %) -80 50))
    "signed byte remainder of division")
(ok (equal? -100 ((jit ctx (list <sint> <sint>) %) -1234 567))
    "signed short integer remainder of division")
(ok (let [(c (list (rgb 2 3 5) (rgb 3 5 7)))]
      (equal? c (to-list ((jit ctx (list (sequence <sintrgb>)) identity) (to-array <sintrgb> c)))))
    "duplicate RGB array")
(ok (equal? 2 ((jit ctx (list <ubytergb>) red) (rgb 2 3 5)))
    "extract red channel of RGB value")
(ok (equal? 3 ((jit ctx (list <ubytergb>) green) (rgb 2 3 5)))
    "extract red channel of RGB value")
(ok (equal? 5 ((jit ctx (list <ubytergb>) blue) (rgb 2 3 5)))
    "extract red channel of RGB value")
(ok (equal? '(2 3) (to-list ((jit ctx (list (sequence <ubytergb>)) red) (seq (rgb 2 3 5) (rgb 3 5 7)))))
    "extract red channel in compiled code")
(ok (equal? '(3 5) (to-list ((jit ctx (list (sequence <ubytergb>)) green) (seq (rgb 2 3 5) (rgb 3 5 7)))))
    "extract green channel in compiled code")
(ok (equal? '(5 7) (to-list ((jit ctx (list (sequence <ubytergb>)) blue) (seq (rgb 2 3 5) (rgb 3 5 7)))))
    "extract blue channel in compiled code")
(ok (equal? '(2 3) (to-list ((jit ctx (list (sequence <ubyte>)) red) (seq 2 3))))
    "extract red channel of scalar array")
(ok (equal? '(2 3) (to-list ((jit ctx (list (sequence <ubyte>)) green) (seq 2 3))))
    "extract green channel of scalar array")
(ok (equal? '(2 3) (to-list ((jit ctx (list (sequence <ubyte>)) blue) (seq 2 3))))
    "extract blue channel of scalar array")
(ok (equal? (list (rgb 2 3 5)) (to-list ((jit ctx (list (sequence <sintrgb>)) (cut to-type <intrgb> <>))
                                         (seq <sintrgb> (rgb 2 3 5)))))
    "convert short integer RGB to integer RGB")
(ok (equal? (list (rgb 2 3 5)) (to-list ((jit ctx (list (sequence <intrgb>)) (cut to-type <bytergb> <>))
                                         (seq <intrgb> (rgb 2 3 5)))))
    "convert integer RGB to byte RGB")
;(ok (equal? (list (rgb -1 -2 3)) (to-list ((jit ctx (list (sequence <bytergb>)) -) (seq (rgb 1 2 -3)))))
;    "negate RGB sequence")
(ok (equal? (list (rgb 5 7 9)) (to-list ((jit ctx (list (sequence <ubytergb>) (sequence <ubytergb>)) +)
                                         (seq (rgb 1 2 3)) (seq (rgb 4 5 6)))))
    "add RGB sequences")
(ok (equal? (list (rgb 2 3 4)) (to-list ((jit ctx (list (sequence <ubytergb>) <ubyte>) +)
                                         (seq (rgb 1 2 3)) 1)))
    "add byte RGB sequence and byte")
(ok (equal? (list (rgb 2 3 4)) (to-list ((jit ctx (list (sequence <byte>) <ubytergb>) +)
                                         (seq <byte> 1) (rgb 1 2 3))))
    "add byte sequence and RGB value")
(ok (equal? (list (rgb 2 3 4)) (to-list ((jit ctx (list <ubytergb> (sequence <byte>)) +)
                                         (rgb 1 2 3) (seq <byte> 1))))
    "add RGB value and byte sequence")
(ok (equal? (rgb 1 2 3) ((jit ctx (list <intrgb>) identity) (rgb 1 2 3)))
    "generate JIT code to return an RGB value")
(ok (equal? (rgb 5 3 1) ((jit ctx (list <ubytergb> <ubytergb>) -) (rgb 6 5 4) (rgb 1 2 3)))
    "subtract RGB values")
(ok (equal? (rgb 254 253 252) ((jit ctx (list <ubytergb>) ~) (rgb 1 2 3)))
    "invert RGB value")
(ok (equal? (rgb 6 35 143) ((jit ctx (list <ubytergb> <ubytergb>) *) (rgb 2 5 11) (rgb 3 7 13)))
    "multiply RGB values")
(ok (equal? (rgb 2 2 4) ((jit ctx (list <ubytergb> <ubyte>) &) (rgb 2 3 4) 254))
    "bitwise and for RGB values")
(ok (equal? (rgb 2 3 6) ((jit ctx (list <ubytergb> <ubyte>) |) (rgb 2 3 4) 2))
    "bitwise or for RGB values")
(ok (equal? (rgb 0 1 6) ((jit ctx (list <ubytergb> <ubyte>) ^) (rgb 2 3 4) 2))
    "bitwise exclusive-or for RGB values")
(ok (equal? (rgb 4 8 12) ((jit ctx (list <ubytergb> <ubyte>) <<) (rgb 1 2 3) 2))
    "left-shift bits of RGB value")
(ok (equal? (rgb 1 2 3) ((jit ctx (list <ubytergb> <ubyte>) >>) (rgb 4 8 12) 2))
    "right-shift bits of RGB value")
(ok (equal? (rgb 1 2 3) ((jit ctx (list <ubytergb> <ubyte>) /) (rgb 3 6 9) 3))
    "divide RGB values")
(ok (equal? (rgb 1 2 0) ((jit ctx (list <ubytergb> <ubyte>) %) (rgb 4 5 6) 3))
    "modulo RGB values")
(ok (equal? '(#t #f) (map (jit ctx (list <bool>) =0) '(#f #t)))
    "boolean negation")
(ok (equal? (rgb 2 3 5) ((jit ctx (list <byte> <byte> <byte>) rgb) 2 3 5))
    "construct RGB value in compiled code")
(ok (equal? (rgb 2 -3 256) ((jit ctx (list <ubyte> <byte> <usint>) rgb) 2 -3 256))
    "construct RGB value from differently typed values")
(ok ((jit ctx (list <ubytergb> <ubytergb>) =) (rgb 2 3 5) (rgb 2 3 5))
    "Compare two RGB values (positive result)")
(ok (not ((jit ctx (list <ubytergb> <ubytergb>) =) (rgb 2 3 5) (rgb 2 4 5)))
    "Compare two RGB values (negative result)")
(ok ((jit ctx (list <ubytergb> <ubytergb>) !=) (rgb 2 3 5) (rgb 2 4 5))
    "Compare two RGB values (positive result)")
(ok (not ((jit ctx (list <ubytergb> <ubytergb>) !=) (rgb 2 3 5) (rgb 2 3 5)))
    "Compare two RGB values (negative result)")
(ok (not ((jit ctx (list <bytergb> <byte>) =) (rgb 2 3 5) 2))
    "Compare  RGB value with scalar (negative result)")
(ok ((jit ctx (list <byte> <bytergb>) =) 3 (rgb 3 3 3))
    "Compare  RGB value with scalar (positive result)")
(ok (equal? 32767 ((jit ctx (list <usint> <usint>) minor) 32767 32768))
    "get minor number of two unsigned integers")
(ok (equal? -1 ((jit ctx (list <sint> <sint>) minor) -1 1))
    "get minor number of two signed integers")
(ok (equal? 32768 ((jit ctx (list <usint> <usint>) major) 32767 32768))
    "get major number of two unsigned integers")
(ok (equal? 1 ((jit ctx (list <sint> <sint>) major) -1 1))
    "get major number of two signed integers")
(ok (equal? 32768 ((jit ctx (list <sint> <usint>) major) -1 32768))
    "get major number of signed and unsigned short integers")
(let [(r (skeleton <ubyte>))
      (a (skeleton <ubyte>))
      (b (skeleton <ubyte>))]
  (ok (equal? (list (CMP DIL SIL) (MOV CL DIL) (MOV DL SIL) (CMOVB CX DX) (MOV AL CL) (RET))
              (assemble r (list a b) (major (parameter a) (parameter b))))
      "handle lack of support for 8-bit conditional move"))
(ok (equal? (list (rgb 2 2 3)) (to-list ((jit ctx (list <ubytergb> (sequence <byte>)) major)
                                         (rgb 1 2 3) (seq <byte> 2))))
    "major value of RGB and byte sequence")
(ok (equal? (list (rgb 1 2 2)) (to-list ((jit ctx (list <ubytergb> (sequence <byte>)) minor)
                                         (rgb 1 2 3) (seq <byte> 2))))
    "minor value of RGB and byte sequence")
