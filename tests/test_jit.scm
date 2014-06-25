(use-modules (oop goops)
             (system foreign)
             (rnrs bytevectors)
             (srfi srfi-26)
             (aiscm jit)
             (aiscm element)
             (aiscm mem)
             (aiscm int)
             (aiscm pointer)
             (guile-tap))
(planned-tests 271)
(define b1 (random (ash 1  6)))
(define b2 (random (ash 1  6)))
(define w1 (random (ash 1 14)))
(define w2 (random (ash 1 14)))
(define i1 (random (ash 1 30)))
(define i2 (random (ash 1 30)))
(define l1 (random (ash 1 62)))
(define l2 (random (ash 1 62)))
(define ctx (make <jit-context>))
(define mem (make <mem> #:size 256))
(define bptr (make (pointer <byte>) #:value mem))
(define wptr (make (pointer <sint>) #:value mem))
(define iptr (make (pointer <int>) #:value mem))
(define lptr (make (pointer <long>) #:value mem))
(define (bdata) (begin
                  (store bptr       (make <sint> #:value b1))
                  (store (+ bptr 1) (make <sint> #:value b2))
                  mem))
(define (wdata) (begin
                  (store wptr       (make <sint> #:value w1))
                  (store (+ wptr 1) (make <sint> #:value w2))
                  mem))
(define (idata) (begin
                  (store iptr       (make <int> #:value i1))
                  (store (+ iptr 1) (make <int> #:value i2))
                  mem))
(define (ldata) (begin
                  (store lptr       (make <long> #:value l1))
                  (store (+ lptr 1) (make <long> #:value l2))
                  mem))
(define (idx) (begin
                (store lptr (make <long> #:value #x0102030405060708))
                mem))
(ok (eqv?  8 (get-bits (class-of AL)))
    "Number of bits of AL")
(ok (eqv? 16 (get-bits (class-of AX)))
    "Number of bits of AX")
(ok (eqv? 32 (get-bits (class-of EAX)))
    "Number of bits of EAX")
(ok (eqv? 64 (get-bits (class-of RAX)))
    "Number of bits of RAX")
(ok (equal? '(#xb8 #x2a #x00 #x00 #x00) (MOV EAX 42))
    "MOV EAX, 42")
(ok (equal? '(#xb9 #x2a #x00 #x00 #x00) (MOV ECX 42))
    "MOV ECX, 42")
(ok (equal? '(#x41 #xb9 #x2a #x00 #x00 #x00) (MOV R9D 42))
    "MOV R9D, 42")
(ok (equal? '(#x48 #xbe #x2a #x00 #x00 #x00 #x00 #x00 #x00 #x00)
            (MOV RSI 42))
    "MOV RSI, 42")
(ok (equal? '(#x49 #xb9 #x2a #x00 #x00 #x00 #x00 #x00 #x00 #x00)
            (MOV R9 42))
    "MOV R9, 42")
(ok (equal? '(#xb0 #x2a) (MOV AL 42))
    "MOV AL, 42")
(ok (equal? '(#x40 #xb7 #x2a) (MOV DIL 42))
    "MOV DIL, 42")
(ok (equal? '(#x66 #xb8 #x2a #x00) (MOV AX 42))
    "MOV AX, 42")
(ok (equal? '(#x8b #xd8) (MOV EBX EAX))
    "MOV EBX, EAX")
(ok (equal? '(#x8b #xca) (MOV ECX EDX))
    "MOV ECX, EDX")
(ok (equal? '(#x45 #x8b #xc1) (MOV R8D R9D))
    "MOV R8D, R9D")
(ok (equal? '(#x8a #xd8) (MOV BL AL))
    "MOV BL, AL")
(ok (equal? '(#x66 #x8b #xd8) (MOV BX AX))
    "MOV BX, AX")
(ok (equal? '(#x8b #x0a) (MOV ECX (dword-ptr RDX)))
    "MOV ECX, [RDX]")
(ok (equal? '(#x48 #x8b #x0a) (MOV RCX (qword-ptr RDX)))
    "MOV RCX, [RDX]")
(ok (equal? '(#x41 #x8b #x0b) (MOV ECX (dword-ptr R11)))
    "MOV ECX, [R11]")
(ok (equal? '(#x8b #x4a #x04) (MOV ECX (dword-ptr RDX 4)))
    "MOV ECX, [RDX] + 4")
(ok (equal? '(#x8b #x8a #x80 #x00 #x00 #x00) (MOV ECX (dword-ptr RDX 128)))
    "MOV ECX, [RDX] + 128")
(ok (equal? '(#x8b #x4c #x24 #x04) (MOV ECX (dword-ptr RSP 4)))
    "MOV ECX, [RSP] + 4")
(ok (equal? '(#x45 #x8b #x53 #x04) (MOV R10D (dword-ptr R11 4)))
    "MOV R10D, [R11] + 4")
(ok (equal? '(#x4d #x8b #x53 #x04) (MOV R10 (qword-ptr R11 4)))
    "MOV R10, [R11] + 4")
(ok (equal? '(#x8a #x0a) (MOV CL (byte-ptr RDX)))
    "MOV CL, [RDX]")
(ok (equal? '(#x66 #x8b #x0a) (MOV CX (word-ptr RDX)))
    "MOV CX, [RDX]")
(ok (equal? '(#x89 #x11) (MOV (dword-ptr RCX) EDX))
    "MOV [RCX], EDX")
(ok (equal? '(#x44 #x89 #x01) (MOV (dword-ptr RCX) R8D))
    "MOV [RCX], R8D")
(ok (equal? '(#xc3) (RET))
    "RET # near return")
(ok (begin ((asm ctx void (list (RET)))) #t)
    "Empty function")
(ok (eqv? i1 ((asm ctx int (list (MOV EAX i1) (RET)))))
    "Return constant in EAX")
(ok (eqv? l1 ((asm ctx long (list (MOV RAX l1) (RET)))))
    "Return constant in RAX")
(ok (eqv? b1 ((asm ctx int8 (list (MOV AL b1) (RET)))))
    "Return constant in AL")
(ok (eqv? w1 ((asm ctx short (list (MOV AX w1) (RET)))))
    "Return constant in AX")
(ok (eqv? i1 ((asm ctx int (list (MOV ECX i1) (MOV EAX ECX) (RET)))))
    "Function copying content from ECX")
(ok (eqv? i1 ((asm ctx int (list (MOV R14D i1) (MOV EAX R14D) (RET)))))
    "Function copying content from R14D")
(ok (eqv? (ash 42 32) ((asm ctx long
                            (list (MOV R14 (ash 42 32))
                                  (MOV RAX R14)
                                  (RET)))))
    "Function copying content from R14")
(ok (eqv? b1 ((asm ctx int (list (MOV DIL b1) (MOV AL DIL) (RET)))))
    "Function copying content from DIL")
(ok (equal? '(#xd1 #xe5) (SHL EBP))
    "SHL EBP, 1")
(ok (equal? '(#x40 #xd0 #xe5) (SHL BPL))
    "SHL BPL, 1")
(ok (equal? '(#x66 #xd1 #xe5) (SHL BP))
    "SHL BP, 1")
(ok (equal? '(#xd1 #xe5) (SAL EBP))
    "SAL EBP, 1")
(ok (eqv? (ash i1 1) ((asm ctx int (list (MOV EAX i1) (SHL EAX) (RET)))))
    "Shift EAX left by 1")
(ok (eqv? (ash i1 1) ((asm ctx int (list (MOV R9D i1)
                                         (SHL R9D)
                                         (MOV EAX R9D)
                                         (RET)))))
    "Shift R9D left by 1")
(ok (eqv? (ash l1 1) ((asm ctx long (list (MOV RAX l1) (SHL RAX) (RET)))))
    "Function shifting 64-bit number left by 1")
(ok (equal? '(#x48 #xd1 #xe5) (SHL RBP))
    "SHL RBP, 1")
(ok (equal? '(#x48 #xd1 #xe5) (SAL RBP))
    "SAL RBP, 1")
(ok (equal? '(#xd1 #xed) (SHR EBP))
    "SHR EBP, 1")
(ok (equal? '(#xd1 #xfd) (SAR EBP))
    "SAR EBP, 1")
(ok (eqv? (ash i1 -1) ((asm ctx int (list (MOV EAX i1) (SHR EAX) (RET)))))
    "Function shifting right by 1")
(ok (eqv? -21 ((asm ctx int (list (MOV EAX -42) (SAR EAX) (RET)))))
    "Function shifting negative number right by 1")
(ok (equal? '(#x48 #xd1 #xed) (SHR RBP))
    "SHR RBP, 1")
(ok (equal? '(#x48 #xd1 #xfd) (SAR RBP))
    "SAR RBP, 1")
(ok (eqv? (ash l1 -1) ((asm ctx long (list (MOV RAX l1) (SHR RAX) (RET)))))
    "Function shifting 64-bit number right by 1")
(ok (eqv? (ash -1 30) ((asm ctx long
                            (list (MOV RAX (ash -1 32))
                                  (SAR RAX)
                                  (SAR RAX)
                                  (RET)))))
    "Function shifting signed 64-bit number right by 2")
(ok (equal? '(#x05 #x0d #x00 #x00 #x00) (ADD EAX 13))
    "ADD EAX, 13")
(ok (equal? '(#x48 #x05 #x0d #x00 #x00 #x00) (ADD RAX 13))
    "ADD RAX, 13")
(ok (equal? '(#x66 #x05 #x0d #x00) (ADD AX 13))
    "ADD AX, 13")
(ok (equal? '(#x04 #x0d) (ADD AL 13))
    "ADD AL, 13")
(ok (equal? '(#x81 #xc1 #x0d #x00 #x00 #x00) (ADD ECX 13))
    "ADD ECX, 13")
(ok (equal? '(#x48 #x81 #xc1 #x0d #x00 #x00 #x00) (ADD RCX 13))
    "ADD RCX, 13")
(ok (equal? '(#x66 #x81 #xc1 #x0d #x00) (ADD CX 13))
    "ADD CX, 13")
(ok (equal? '(#x80 #xc1 #x0d) (ADD CL 13))
    "ADD CL, 13")
(ok (equal? '(#x41 #x81 #xc2 #x0d #x00 #x00 #x00) (ADD R10D 13))
    "ADD R10D, 13")
(ok (equal? '(#x49 #x81 #xc2 #x0d #x00 #x00 #x00) (ADD R10 13))
    "ADD R10, 13")
(ok (equal? '(#x80 #x07 #x2a) (ADD (byte-ptr RDI) 42))
    "ADD BYTE PTR [RDI], 42")
(ok (equal? '(#x03 #xca) (ADD ECX EDX))
    "ADD ECX, EDX")
(ok (equal? '(#x45 #x03 #xf7) (ADD R14D R15D))
    "ADD R14D, R15D")
(ok (equal? '(#x66 #x03 #xca) (ADD CX DX))
    "ADD CX, DX")
(ok (equal? '(#x02 #xca) (ADD CL DL))
    "ADD CL, DL")
(ok (equal? '(#x03 #x0a) (ADD ECX (dword-ptr RDX)))
    "ADD ECX, [RDX]")
(ok (equal? '(#x2d #x0d #x00 #x00 #x00) (SUB EAX 13))
    "SUB EAX, 13")
(ok (equal? '(#x48 #x2d #x0d #x00 #x00 #x00) (SUB RAX 13))
    "SUB RAX, 13")
(ok (equal? '(#x41 #x81 #xea #x0d #x00 #x00 #x00) (SUB R10D 13))
    "SUB R10D, 13")
(ok (equal? '(#x49 #x81 #xea #x0d #x00 #x00 #x00) (SUB R10 13))
    "SUB R10, 13")
(ok (equal? '(#x41 #x81 #x2a #x0d #x00 #x00 #x00) (SUB (dword-ptr R10) 13))
    "SUB (dword-ptr R10), 13")
(ok (equal? '(#x2b #xca) (SUB ECX EDX))
    "SUB ECX, EDX")
(ok (equal? '(#x45 #x2b #xf7) (SUB R14D R15D))
    "SUB R14D, R15D")
(ok (eqv? 55 ((asm ctx int (list (MOV EAX 42) (ADD EAX 13) (RET)))))
    "Function using EAX to add 42 and 13")
(ok (eqv? 55 ((asm ctx long (list (MOV RAX 42) (ADD RAX 13) (RET)))))
    "Function using RAX to add 42 and 13")
(ok (eqv? 55 ((asm ctx int16 (list (MOV AX 42) (ADD AX 13) (RET)))))
    "Function using AX to add 42 and 13")
(ok (eqv? 55 ((asm ctx int8 (list (MOV AL 42) (ADD AL 13) (RET)))))
    "Function using AL to add 42 and 13")
(ok (eqv? 55 ((asm ctx int (list (MOV R9D 42) (ADD R9D 13) (MOV EAX R9D) (RET)))))
    "Function using R9D to add 42 and 13")
(ok (eqv? 55 ((asm ctx long (list (MOV R9 42) (ADD R9 13) (MOV RAX R9) (RET)))))
    "Function using R9 to add 42 and 13")
(ok (eqv? 55 ((asm ctx int16 (list (MOV R9W 42) (ADD R9W 13) (MOV AX R9W) (RET)))))
    "Function using R9W to add 42 and 13")
(ok (eqv? 55 ((asm ctx int8 (list (MOV R9L 42) (ADD R9L 13) (MOV AL R9L) (RET)))))
    "Function using R9L to add 42 and 13")
(ok (eqv? (+ i1 i2) ((asm ctx int (list (MOV EAX i1) (ADD EAX i2) (RET)))))
    "Function adding two integers in EAX")
(ok (eqv? (+ i1 i2) ((asm ctx int (list (MOV EDX i1) (ADD EDX i2) (MOV EAX EDX) (RET)))))
    "Function adding two integers in EDX")
(ok (eqv? (+ i1 i2) ((asm ctx int (list (MOV R10D i1) (ADD R10D i2) (MOV EAX R10D) (RET)))))
    "Function adding two integers in R10D")
(ok (eqv? (+ i1 i2) ((asm ctx int (list (MOV EAX i1) (MOV ECX i2) (ADD EAX ECX) (RET)))))
    "Function using EAX and ECX to add two integers")
(ok (eqv? (+ i1 i2) ((asm ctx int (list (MOV R14D i1) (MOV R15D i2) (ADD R14D R15D) (MOV EAX R14D) (RET)))))
    "Function using R14D and R15D to add two integers")
(ok (eqv? (+ w1 w2) ((asm ctx int16 (list (MOV AX w1) (MOV CX w2) (ADD AX CX) (RET)))))
    "Function using AX and CX to add two short integers")
(ok (eqv? (+ b1 b2) ((asm ctx int8 (list (MOV AL b1) (MOV CL b2) (ADD AL CL) (RET)))))
    "Function using AL and CL to add two bytes")
(ok (eqv? (+ i1 i2) ((asm ctx int (list (MOV EAX i2) (MOV RDX (idata)) (ADD EAX (dword-ptr RDX)) (RET)))))
    "Add integer memory operand")
(ok (eqv? (+ i1 i2) (begin ((asm ctx void
                                 (list (MOV RSI mem)
                                       (MOV (dword-ptr RSI) i1)
                                       (ADD (dword-ptr RSI) i2)
                                       (RET))))
                    (get-value (fetch iptr))))
    "Add integer to integer in memory")
(ok (equal? '(#x90) (NOP))
    "NOP # no operation")
(ok (eqv? i1 ((asm ctx int (list (MOV EAX i1) (NOP) (NOP) (RET)))))
    "Function with some NOP statements inside")
(ok (equal? '(#x52) (PUSH EDX))
    "PUSH EDX")
(ok (equal? '(#x57) (PUSH EDI))
    "PUSH EDI")
(ok (equal? '(#x5a) (POP EDX))
    "POP EDX")
(ok (equal? '(#x5f) (POP EDI))
    "POP EDI")
(ok (eqv? i1 ((asm ctx long (list (MOV EDX i1) (PUSH EDX) (POP EAX) (RET)))))
    "Use 32-bit PUSH and POP")
(ok (eqv? l1 ((asm ctx long (list (MOV RDX l1) (PUSH RDX) (POP RAX) (RET)))))
    "Use 64-bit PUSH and POP")
(ok (eqv? w1 ((asm ctx long (list (MOV DX w1) (PUSH DX) (POP AX) (RET)))))
    "Use 16-bit PUSH and POP")
(ok (eqv? i1 ((asm ctx int (list (MOV RCX (idata)) (MOV EAX (dword-ptr RCX)) (RET)))))
    "Load integer from address in RCX")
(ok (eqv? i1 ((asm ctx int (list (MOV R10 (idata)) (MOV EAX (dword-ptr R10)) (RET)))))
    "Load integer from address in R10")
(ok (eqv? i2 ((asm ctx int (list (MOV RCX (idata)) (MOV EAX (dword-ptr RCX 4)) (RET)))))
    "Load integer from address in RCX with offset")
(ok (eqv? i1 ((asm ctx int (list (MOV RCX (get-value (+ iptr 50))) (MOV EAX (dword-ptr RCX -200)) (RET)))))
    "Load integer from address in RCX with large offset")
(ok (eqv? i2 ((asm ctx int (list (MOV R9 (idata)) (MOV EAX (dword-ptr R9 4)) (RET)))))
    "Load integer from address in R9D with offset")
(ok (eqv? l1 ((asm ctx long (list (MOV RCX (ldata)) (MOV RAX (qword-ptr RCX)) (RET)))))
    "Load long integer from address in RCX")
(ok (eqv? l2 ((asm ctx long (list (MOV RCX (ldata)) (MOV RAX (qword-ptr RCX 8)) (RET)))))
    "Load long integer from address in RCX with offset")
(ok (eqv? w1 ((asm ctx short (list (MOV RCX (wdata)) (MOV AX (word-ptr RCX)) (RET)))))
    "Load short integer from address in RCX")
(ok (eqv? w2 ((asm ctx short (list (MOV RCX (wdata)) (MOV AX (word-ptr RCX 2)) (RET)))))
    "Load short integer from address in RCX with offset")
(ok (eqv? b1 ((asm ctx int8 (list (MOV RCX (bdata)) (MOV AL (byte-ptr RCX)) (RET)))))
    "Load byte from address in RCX")
(ok (eqv? b2 ((asm ctx int8 (list (MOV RCX (bdata)) (MOV AL (byte-ptr RCX 1)) (RET)))))
    "Load byte from address in RCX with offset")
(ok (equal? '(#x48 #x8d #x51 #x04) (LEA RDX (qword-ptr RCX 4)))
    "LEA RDX, [RCX + 4]")
(ok (equal? '(#x48 #x8d #x44 #x24 #xfc) (LEA RAX (qword-ptr RSP -4)))
    "LEA RAX, [RSP - 4]")
(ok (eqv? i2 ((asm ctx int (list (MOV RCX (idata))
                                 (LEA RDX (qword-ptr RCX 4))
                                 (MOV EAX (dword-ptr RDX))
                                 (RET)))))
    "Load integer from address in RCX with offset using effective address")
(ok (equal? '(#x48 #x8d #x04 #xb7) (LEA RAX (qword-ptr RDI RSI *4)))
    "LEA RAX, [RDI + ESI * 4]")
(ok (eqv? i2 ((asm ctx int (list (MOV RCX (idata))
                                 (MOV RDI 1)
                                 (LEA RDX (qword-ptr RCX RDI *4))
                                 (MOV EAX (dword-ptr RDX))
                                 (RET)))))
    "Load integer from address in RCX with index times 4 using effective address")
(ok (equal? '(#x48 #x8d #x04 #x77) (LEA RAX (qword-ptr RDI RSI *2)))
    "LEA RAX, [RDI + ESI * 2]")
(ok (eqv? i2 ((asm ctx int (list (MOV RCX (idata))
                                 (MOV RDI 2)
                                 (LEA RDX (qword-ptr RCX RDI *2))
                                 (MOV EAX (dword-ptr RDX))
                                 (RET)))))
    "Load integer from address in RCX with index times 2 using effective address")
(ok (equal? '(#x48 #x8d #x44 #x77 #x02) (LEA RAX (qword-ptr RDI RSI *2 2)))
    "LEA RAX, [RDI + ESI * 2 + 2]")
(ok (eqv? i2 ((asm ctx int (list (MOV RCX (idata))
                                 (MOV RDI 3)
                                 (LEA RDX (qword-ptr RCX RDI *1 1))
                                 (MOV EAX (dword-ptr RDX))
                                 (RET)))))
    "Load integer from address in RCX with index and offset using effective address")
(ok (eqv? i2 ((asm ctx int (list (MOV R9 (idata))
                                 (MOV R10 3)
                                 (LEA R11 (qword-ptr R9 R10 *1 1))
                                 (MOV EAX (dword-ptr R11))
                                 (RET)))))
    "Load integer from address in R9 with index and offset using effective address")
(ok (eqv? #x08 (begin ((asm ctx long
                            (list (MOV RDI (idx))
                                  (MOV AL (byte-ptr RDI))
                                  (RET))))))
    "Load 8-bit value from memory")
(ok (eqv? #x0708 (begin ((asm ctx long
                              (list (MOV RDI (idx))
                                    (MOV AX (word-ptr RDI))
                                    (RET))))))
    "Load 16-bit value from memory")
(ok (eqv? #x05060708 (begin ((asm ctx long
                                  (list (MOV RDI (idx))
                                        (MOV EAX (dword-ptr RDI))
                                        (RET))))))
    "Load 32-bit value from memory")
(ok (eqv? #x0102030405060708 (begin ((asm ctx long
                                          (list (MOV RDI (idx))
                                                (MOV RAX (qword-ptr RDI))
                                                (RET))))))
    "Load 64-bit value from memory")
(ok (eqv? i1 (begin ((asm ctx void
                          (list (MOV RSI mem)
                                (MOV ECX i1)
                                (MOV (dword-ptr RSI) ECX)
                                (RET))))
                    (get-value (fetch iptr))))
    "Write value of ECX to memory")
(ok (eqv? l1 (begin ((asm ctx void
                          (list (MOV RSI mem)
                                (MOV RCX l1)
                                (MOV (qword-ptr RSI) RCX)
                                (RET))))
                    (get-value (fetch lptr))))
    "Write value of RCX to memory")
(ok (eqv? i1 (begin ((asm ctx int
                          (list (MOV RSI mem)
                                (MOV R8D i1)
                                (MOV (dword-ptr RSI) R8D)
                                (RET))))
                    (get-value (fetch iptr))))
    "Write value of R8D to memory")
(ok (eqv? i1 (begin ((asm ctx void
                          (list (MOV RSI mem)
                                (MOV ECX i1)
                                (MOV (dword-ptr RSI) ECX)
                                (RET))))
                    (get-value (fetch iptr))))
    "Write value of ECX to memory")
(ok (equal? '(#xc7 #x07 #x2a #x00 #x00 #x00) (MOV (dword-ptr RDI) 42))
    "MOV DWORD PTR [RDI], 42")
(ok (equal? '(#x48 #xc7 #x07 #x2a #x00 #x00 #x00) (MOV (qword-ptr RDI) 42))
    "MOV QWORD PTR [RDI], 42")
(ok (equal? '(#x66 #xc7 #x07 #x2a #x00) (MOV (word-ptr RDI) 42))
    "MOV WORD PTR [RDI], 42")
(ok (equal? '(#xc6 #x07 #x2a) (MOV (byte-ptr RDI) 42))
    "MOV BYTE PTR [RDI], 42")
(ok (eqv? #x0102030405060700 (begin ((asm ctx void
                                          (list (MOV RDI (idx))
                                                (MOV (byte-ptr RDI) 0)
                                                (RET))))
                                    (get-value (fetch lptr))))
    "Write 8-bit value to memory")
(ok (eqv? #x0102030405060000 (begin ((asm ctx void
                                          (list (MOV R10 (idx))
                                                (MOV (word-ptr R10) 0)
                                                (RET))))
                                    (get-value (fetch lptr))))
    "Write 16-bit value to memory")
(ok (eqv? #x0102030400000000 (begin ((asm ctx void
                                          (list (MOV RDI (idx))
                                                (MOV (dword-ptr RDI) 0)
                                                (RET))))
                                    (get-value (fetch lptr))))
    "Write 32-bit value to memory")
(ok (eqv? #x0000000000000000 (begin ((asm ctx void
                                          (list (MOV RDI (idx))
                                                (MOV (qword-ptr RDI) 0)
                                                (RET))))
                                    (get-value (fetch lptr))))
    "Write 64-bit value to memory")
(ok (eqv? 2 ((asm ctx int (list (MOV EAX EDI) (RET))
                  int int int int) 2 3 5 7))
    "Function return first integer argument")
(ok (eqv? 3 ((asm ctx int (list (MOV EAX ESI) (RET))
                  int int int int) 2 3 5 7))
    "Function return second integer argument")
(ok (eqv? 5 ((asm ctx int (list (MOV EAX EDX) (RET))
                  int int int int) 2 3 5 7))
    "Function return third integer argument")
(ok (eqv? 7 ((asm ctx int (list (MOV EAX ECX) (RET))
                  int int int int) 2 3 5 7))
    "Function return fourth integer argument")
(ok (eqv? 11 ((asm ctx int (list (MOV EAX R8D) (RET))
                   int int int int int int) 2 3 5 7 11 13))
    "Function return fifth integer argument")
(ok (eqv? 13 ((asm ctx int (list (MOV EAX R9D) (RET))
                   int int int int int int) 2 3 5 7 11 13))
    "Function return sixth integer argument")
(ok (eqv? 17 ((asm ctx int (list (MOV EAX (dword-ptr RSP #x8)) (RET))
                   int int int int int int int int) 2 3 5 7 11 13 17 19))
    "Function return seventh integer argument")
(ok (eqv? 19 ((asm ctx int (list (MOV EAX (dword-ptr RSP #x10)) (RET))
                   int int int int int int int int) 2 3 5 7 11 13 17 19))
    "Function return eighth integer argument")
(ok (equal? '(#xf7 #xdb) (NEG EBX))
    "NEG EBX")
(ok (equal? '(#x66 #xf7 #xdb) (NEG BX))
    "NEG BX")
(ok (equal? '(#xf6 #xdb) (NEG BL))
    "NEG BL")
(ok (eqv? (- i1) ((asm ctx int (list (MOV EAX EDI) (NEG EAX) (RET)) int) i1))
    "Function negating an integer")
(ok (eqv? (- l1) ((asm ctx long (list (MOV RAX RDI) (NEG RAX) (RET)) long) l1))
    "Function negating a long integer")
(ok (eqv? (- w1) ((asm ctx short (list (MOV AX DI) (NEG AX) (RET)) short) w1))
    "Function negating a short integer")
(ok (eqv? (- b1) ((asm ctx int8 (list (MOV AL DIL) (NEG AL) (RET)) int8) b1))
    "Function negating a byte")
(ok (eqv? (- i1 i2) ((asm ctx int
                          (list (MOV EAX i1)
                                (SUB EAX i2)
                                (RET)))))
    "Function subtracting two integers in EAX")
(ok (eqv? (- i1 i2) ((asm ctx int
                          (list (MOV EDX i1)
                                (SUB EDX i2)
                                (MOV EAX EDX)
                                (RET)))))
    "Function subtracting two integers in EDX")
(ok (eqv? (- i1 i2) ((asm ctx int
                          (list (MOV R10D i1)
                                (SUB R10D i2)
                                (MOV EAX R10D)
                                (RET)))))
    "Function subtracting two integers in R10D")
(ok (eqv? (- i1 i2) ((asm ctx int
                          (list (MOV EAX i1)
                                (MOV ECX i2)
                                (SUB EAX ECX)
                                (RET)))))
    "Function using EAX and ECX to subtract two integers")
(ok (eqv? (- i1 i2) ((asm ctx int
                          (list (MOV R14D i1)
                                (MOV R15D i2)
                                (SUB R14D R15D)
                                (MOV EAX R14D)
                                (RET)))))
    "Function using R14D and R15D to subtract two integers")
(ok (not (throws? (asm ctx int (list (MOV EAX i1) 'tst (RET)))))
    "Assembler should tolerate labels")
(ok (eqv? 0 (assq-ref (label-offsets (list 'tst)) 'tst))
    "Sole label maps to zero")
(ok (eqv? 0 (assq-ref (label-offsets (list 'tst (NOP))) 'tst))
    "Label at beginning of code is zero")
(ok (eqv? (length (MOV EAX ESI))
          (assq-ref (label-offsets (list (MOV EAX ESI) 'tst)) 'tst))
    "Label after MOV EAX ESI statement maps to length of that statement")
(ok (equal? '(1 2) (let [(a (label-offsets (list (NOP) 'x (NOP) 'y)))]
                     (map (cut assq-ref a <>) '(x y))))
    "Map multiple labels")
(ok (equal? '(#xeb #x2a) (JMP 42))
    "JMP 42")
(ok (eq? 'tst (get-target (JMP 'tst)))
    "Target of JMP to label")
(ok (eqv? 2 (len (JMP 'tst)))
    "Length of JMP")
(ok (eqv? 2 (assq-ref (label-offsets (list (JMP 'tst) 'tst)) 'tst))
    "Label after JMP statement maps to 2")
(ok (equal? (JMP 5) (resolve (JMP 'tst) 0 '((tst . 5))))
    "Resolve jump address with zero offset")
(ok (equal? (JMP 3) (resolve (JMP 'tst) 2 '((tst . 5))))
    "Resolve jump address with offset 2")
(ok (equal? (list (JMP 5)) (resolve-jumps (list (JMP 'tst)) '((tst . 7))))
    "Resolve jump address in trivial program")
(ok (equal? (list (JMP 5) (NOP)) (resolve-jumps (list (JMP 'tst) (NOP)) '((tst . 7))))
    "Resolve jump address in program with trailing NOP")
(ok (equal? (list (NOP) (JMP 4)) (resolve-jumps (list (NOP) (JMP 'tst)) '((tst . 7))))
    "Resolve jump address in program with leading NOP")
(ok (equal? (list (NOP) (NOP)) (resolve-jumps (list (NOP) 'tst (NOP)) '()))
    "Remove label information from program")
(ok (eqv? i1 ((asm ctx int
                   (list (MOV ECX i1)
                         (JMP 'tst)
                         (MOV ECX 0)
                         'tst
                         (MOV EAX ECX)
                         (RET)))))
    "Function with a local jump")
(ok (eqv? i1 ((asm ctx int
                   (list (MOV EAX 0)
                         (JMP 'b)
                         'a
                         (MOV EAX i1)
                         (JMP 'c)
                         'b
                         (MOV EAX i2)
                         (JMP 'a)
                         'c
                         (RET)))))
    "Function with several local jumps")
(ok (equal? '(#x3d #x2a #x00 #x00 #x00) (CMP EAX 42))
    "CMP EAX 42")
(ok (equal? '(#x48 #x3d #x2a #x00 #x00 #x00) (CMP RAX 42))
    "CMP RAX 42")
(ok (equal? '(#x41 #x81 #xfa #x2a #x00 #x00 #x00) (CMP R10D 42))
    "CMP R10D 42")
(ok (equal? '(#x49 #x81 #xfa #x2a #x00 #x00 #x00) (CMP R10 42))
    "CMP R10 42")
(ok (equal? '(#x41 #x0f #x94 #xc1) (SETE R9L))
    "SETE R9L")
(ok (eqv? 1 ((asm ctx int8 (list (MOV EAX EDI) (CMP EAX 0) (SETE AL) (RET)) int) 0))
    "Compare zero in EAX with zero")
(ok (eqv? 0 ((asm ctx int8 (list (MOV EAX EDI) (CMP EAX 0) (SETE AL) (RET)) int) (logior 1 i1)))
    "Compare non-zero number in EAX with zero")
(ok (equal? '(#x41 #x81 #xfa #x2a #x00 #x00 #x00) (CMP R10D 42))
    "CMP R10D 42")
(ok (eqv? 1 ((asm ctx int8 (list (MOV R10D EDI) (CMP R10D 0) (SETE AL) (RET)) int) 0))
    "Compare zero in R10D with zero")
(ok (eqv? 0 ((asm ctx int8 (list (MOV R10D EDI) (CMP R10D 0) (SETE AL) (RET)) int) (logior 1 i1)))
    "Compare non-zero number in R10D with zero")
(ok (equal? '(#x3b #xfe) (CMP EDI ESI))
    "CMP EDI ESI")
(ok (eqv? 1 ((asm ctx int8 (list (CMP EDI ESI) (SETE AL) (RET)) int int) i1 i1))
    "Two integers being equal")
(ok (eqv? 0 ((asm ctx int8 (list (CMP EDI ESI) (SETE AL) (RET)) int int) i1 (logxor 1 i1)))
    "Two integers not being equal")
(ok (equal? '(#x48 #x3b #xf7) (CMP RSI RDI))
    "CMP RSI RDI")
(ok (eqv? 1 ((asm ctx int8 (list (CMP RSI RDI) (SETE AL) (RET)) long long) l1 l1))
    "Two long integers being equal")
(ok (eqv? 0 ((asm ctx int8 (list (CMP RSI RDI) (SETE AL) (RET)) long long) l1 (logxor 1 l1)))
    "Two long integers not being equal")
(ok (equal? '(#x41 #x0f #x92 #xc1) (SETB R9L))
    "SETB R9L")
(ok (eqv? 1 ((asm ctx int8 (list (CMP EDI ESI) (SETB AL) (RET)) uint32 uint32) 1 3))
    "Unsigned integer being below another")
(ok (eqv? 0 ((asm ctx int8 (list (CMP EDI ESI) (SETB AL) (RET)) uint32 uint32) 3 3))
    "Unsigned integer not being below another")
(ok (equal? '(#x41 #x0f #x93 #xc1) (SETNB R9L))
    "SETNB R9L")
(ok (eqv? 0 ((asm ctx int8 (list (CMP EDI ESI) (SETNB AL) (RET)) uint32 uint32) 1 3))
    "Unsigned integer not being above or equal")
(ok (eqv? 1 ((asm ctx int8 (list (CMP EDI ESI) (SETNB AL) (RET)) uint32 uint32) 3 3))
    "Unsigned integer being above or equal")
(ok (equal? '(#x41 #x0f #x95 #xc1) (SETNE R9L))
    "SETNE R9L")
(ok (eqv? 0 ((asm ctx int8 (list (CMP EDI ESI) (SETNE AL) (RET)) int int) i1 i1))
    "Two integers not being unequal")
(ok (eqv? 1 ((asm ctx int8 (list (CMP EDI ESI) (SETNE AL) (RET)) int int) i1 (logxor 1 i1)))
    "Two integers being unequal")
(ok (equal? '(#x41 #x0f #x96 #xc1) (SETBE R9L))
    "SETBE R9L")
(ok (eqv? 1 ((asm ctx int8 (list (CMP EDI ESI) (SETBE AL) (RET)) uint32 uint32) 3 3))
    "Unsigned integer being below or equal")
(ok (eqv? 0 ((asm ctx int8 (list (CMP EDI ESI) (SETBE AL) (RET)) uint32 uint32) 4 3))
    "Unsigned integer not being below or equal")
(ok (equal? '(#x41 #x0f #x97 #xc1) (SETNBE R9L))
    "SETNBE R9L")
(ok (eqv? 0 ((asm ctx int8 (list (CMP EDI ESI) (SETNBE AL) (RET)) uint32 uint32) 3 3))
    "Unsigned integer not being above")
(ok (eqv? 1 ((asm ctx int8 (list (CMP EDI ESI) (SETNBE AL) (RET)) uint32 uint32) 4 3))
    "Unsigned integer being above")
(ok (equal? '(#x41 #x0f #x9c #xc1) (SETL R9L))
    "SETL R9L")
(ok (eqv? 1 ((asm ctx int8 (list (CMP EDI ESI) (SETL AL) (RET)) int int) -2 3))
    "Signed integer being less")
(ok (eqv? 0 ((asm ctx int8 (list (CMP EDI ESI) (SETL AL) (RET)) int int) 3 3))
    "Signed integer not being less")
(ok (equal? '(#x41 #x0f #x9d #xc1) (SETNL R9L))
    "SETNL R9L")
(ok (eqv? 0 ((asm ctx int8 (list (CMP EDI ESI) (SETNL AL) (RET)) int int) -2 3))
    "Signed integer not being greater or equal")
(ok (eqv? 1 ((asm ctx int8 (list (CMP EDI ESI) (SETNL AL) (RET)) int int) 3 3))
    "Signed integer being greater or equal")
(ok (equal? '(#x41 #x0f #x9e #xc1) (SETLE R9L))
    "SETLE R9L")
(ok (eqv? 1 ((asm ctx int8 (list (CMP EDI ESI) (SETLE AL) (RET)) int int) -2 -2))
    "Signed integer being less or equal")
(ok (eqv? 0 ((asm ctx int8 (list (CMP EDI ESI) (SETLE AL) (RET)) int int) 3 -2))
    "Signed integer not being less or equal")
(ok (equal? '(#x41 #x0f #x9f #xc1) (SETNLE R9L))
    "SETNLE R9L")
(ok (eqv? 0 ((asm ctx int8 (list (CMP EDI ESI) (SETNLE AL) (RET)) int int) -2 -2))
    "Signed integer not being greater")
(ok (eqv? 1 ((asm ctx int8 (list (CMP EDI ESI) (SETNLE AL) (RET)) int int) 3 -2))
    "Signed integer being greater")
(ok (equal? '(#x74 #x2a) (JE 42))
    "JE 42")
(ok (eq? 'tst (get-target (JE 'tst)))
    "Target of JE to label")
(ok (eqv? 2 (len (JE 'tst)))
    "Length of JE")
(ok (eqv? 1 ((asm ctx int (list (MOV EAX 1) (CMP EAX 1) (JE 'l) (MOV EAX 0) 'l (RET)))))
    "Test JE with ZF=1")
(ok (eqv? 0 ((asm ctx int (list (MOV EAX 2) (CMP EAX 1) (JE 'l) (MOV EAX 0) 'l (RET)))))
    "Test JE with ZF=0")
(ok (equal? '(#x72 #x2a) (JB 42))
    "JB 42")
(ok (eqv? 3 ((asm ctx int (list (MOV EAX EDI) (CMP EAX 5) (JB 'l) (MOV EAX 5) 'l (RET)) int) 3))
    "Test JB with CF=1")
(ok (eqv? 5 ((asm ctx int (list (MOV EAX EDI) (CMP EAX 5) (JB 'l) (MOV EAX 5) 'l (RET)) int) 7))
    "Test JB with CF=0")
(ok (equal? '(#x75 #x2a) (JNE 42))
    "JNE 42")
(ok (equal? '(#x76 #x2a) (JBE 42))
    "JBE 42")
(ok (equal? '(#x77 #x2a) (JNBE 42))
    "JNBE 42")
(ok (equal? '(#x7c #x2a) (JL 42))
    "JL 42")
(ok (equal? '(#x7d #x2a) (JNL 42))
    "JNL 42")
(ok (equal? '(#x7e #x2a) (JLE 42))
    "JLE 42")
(ok (equal? '(#x7f #x2a) (JNLE 42))
    "JNLE 42")
(ok (equal? '(#x66 #x0f #xbe #xca) (MOVSX CX DL))
    "MOVSX CX DL")
(ok (eqv? b1 ((asm ctx int16 (list (MOV AX w1) (MOV CL b1) (MOVSX AX CL) (RET)))))
    "Convert byte to short integer")
(ok (eqv? -42 ((asm ctx int16 (list (MOV AX w1) (MOV CL -42) (MOVSX AX CL) (RET)))))
    "Convert negative byte to short integer")
(ok (equal? '(#x0f #xbe #xca) (MOVSX ECX DL))
    "MOVSX ECX DL")
(ok (eqv? b1 ((asm ctx int (list (MOV EAX i1) (MOV CL b1) (MOVSX EAX CL) (RET)))))
    "Convert byte to integer")
(ok (eqv? -42 ((asm ctx int (list (MOV EAX i1) (MOV CL -42) (MOVSX EAX CL) (RET)))))
    "Convert negative byte to integer")
(ok (equal? '(#x48 #x0f #xbe #xca) (MOVSX RCX DL))
    "MOVSX RCX DL")
(ok (eqv? b1 ((asm ctx long (list (MOV RAX l1) (MOV CL b1) (MOVSX RAX CL) (RET)))))
    "Convert byte to short integer")
(ok (eqv? -42 ((asm ctx long (list (MOV RAX l1) (MOV CL -42) (MOVSX RAX CL) (RET)))))
    "Convert negative byte to short integer")
(ok (equal? '(#x0f #xbf #xca) (MOVSX ECX DX))
    "MOVSX ECX DX")
(ok (eqv? w1 ((asm ctx int (list (MOV EAX i1) (MOV CX w1) (MOVSX EAX CX) (RET)))))
    "Convert short integer to integer")
(ok (eqv? -42 ((asm ctx int (list (MOV EAX i1) (MOV CX -42) (MOVSX EAX CX) (RET)))))
    "Convert negative short integer to integer")
(ok (equal? '(#x48 #x0f #xbf #xca) (MOVSX RCX DX))
    "MOVSX RCX DX")
(ok (eqv? w1 ((asm ctx long (list (MOV RAX l1) (MOV CX w1) (MOVSX RAX CX) (RET)))))
    "Convert short integer to long integer")
(ok (eqv? -42 ((asm ctx long (list (MOV RAX l1) (MOV CX -42) (MOVSX RAX CX) (RET)))))
    "Convert negative short integer to long integer")
(ok (equal? '(#x48 #x63 #xca) (MOVSX RCX EDX))
    "MOVSX RCX EDX")
(ok (eqv? i1 ((asm ctx long (list (MOV RAX l1) (MOV ECX i1) (MOVSX RAX ECX) (RET)))))
    "Convert integer to long integer")
(ok (eqv? -42 ((asm ctx long (list (MOV RAX l1) (MOV ECX -42) (MOVSX RAX ECX) (RET)))))
    "Convert negative integer to long integer")
(ok (equal? '(#x66 #x0f #xb6 #xc8) (MOVZX CX AL))
    "MOVZX CX AL")
(ok (eqv? b1 ((asm ctx uint16 (list (MOV AX w1) (MOV CL b1) (MOVZX AX CL) (RET)))))
    "Convert unsigned byte to unsigned short integer")
(ok (equal? '(#x0f #xb6 #xc8) (MOVZX ECX AL))
    "MOVZX ECX AL")
(ok (eqv? b1 ((asm ctx uint32 (list (MOV EAX i1) (MOV CL b1) (MOVZX EAX CL) (RET)))))
    "Convert unsigned byte to unsigned integer")
(ok (equal? '(#x0f #xb7 #xc8) (MOVZX ECX AX))
    "MOVZX ECX AX")
(ok (eqv? w1 ((asm ctx uint32 (list (MOV EAX i1) (MOV CX w1) (MOVZX EAX CX) (RET)))))
    "Convert unsigned short integer to unsigned integer")
(ok (equal? '(#x0f #xb7 #xc8) (MOVZX ECX AX))
    "MOVZX ECX AX")
(ok (eqv? w1 ((asm ctx uint32 (list (MOV EAX i1) (MOV CX w1) (MOVZX EAX CX) (RET)))))
    "Convert unsigned short integer to unsigned integer")
(ok (equal? '(#x0f #xb7 #xc8) (MOVZX ECX AX))
    "MOVZX ECX AX")
(ok (eqv? w1 ((asm ctx uint64 (list (MOV RAX l1) (MOV CX w1) (MOVZX RAX CX) (RET)))))
    "Convert unsigned short integer to unsigned long integer")
(ok (eqv? i1 ((asm ctx uint64 (list (MOV RAX l1) (MOV ECX i1) (MOV RAX ECX) (RET)))))
    "Convert unsigned integer to unsigned long integer")
(ok (eqv? 42 ((asm ctx int (list (PUSH RBX) (MOV EBX 42) (MOV EAX EBX) (POP RBX) (RET)))))
    "Save and restore value of RBX using the stack (this will crash if it does not restore RBX properly)")
(ok (eqv? 42 ((asm ctx int (list (MOV (qword-ptr RSP -8) RBX)
                                 (SUB RSP 8)
                                 (MOV EBX 42)
                                 (MOV EAX EBX)
                                 (MOV RBX (qword-ptr RSP))
                                 (ADD RSP 8)
                                 (RET)))))
    "Explicitely manage stack pointer (this will crash if it does not restore RBX and RSP properly)")
(ok (equal? EDX
            (let [(pool (make <pool> #:registers (list EDX ECX)))]
              (environment pool
                           [(x (container pool <reg<32>>))]
                           x)))
    "Get first register from pool")
(ok (equal? ECX
            (let [(pool (make <pool> #:registers (list EDX ECX)))]
              (environment pool
                           [(x (container pool <reg<32>>))
                            (y (container pool <reg<32>>))]
                           y)))
    "Get second register from pool")
(ok (equal? EDX
            (let [(pool (make <pool> #:registers (list EDX ECX)))]
              (environment pool [(x (container pool <reg<32>>))] x)
              (environment pool [(x (container pool <reg<32>>))] x)))
    "Reuse register from pool")
(format #t "~&")
