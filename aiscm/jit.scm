;; AIscm - Guile extension for numerical arrays and tensors.
;; Copyright (C) 2013, 2014, 2015, 2016, 2017 Jan Wedekind <jan@wedesoft.de>
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;
(define-module (aiscm jit)
  #:use-module (oop goops)
  #:use-module (ice-9 optargs)
  #:use-module (ice-9 curried-definitions)
  #:use-module (ice-9 binary-ports)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (aiscm util)
  #:use-module (aiscm asm)
  #:use-module (aiscm element)
  #:use-module (aiscm scalar)
  #:use-module (aiscm pointer)
  #:use-module (aiscm bool)
  #:use-module (aiscm int)
  #:use-module (aiscm float)
  #:use-module (aiscm obj)
  #:use-module (aiscm composite)
  #:use-module (aiscm sequence)
  #:use-module (aiscm variable)
  #:use-module (aiscm command)
  #:use-module (aiscm program)
  #:use-module (aiscm register-allocate)
  #:use-module (aiscm method)
  #:export (<block> <param> <indexer> <lookup> <function> <loop-detail> <tensor-loop>
            replace-variables adjust-stack-pointer default-registers
            register-parameters stack-parameters
            register-parameter-locations stack-parameter-locations parameter-locations
            need-to-copy-first move-variable-content update-parameter-locations
            place-result-variable used-callee-saved backup-registers add-stack-parameter-information
            number-spilled-variables temporary-variables unit-intervals temporary-registers
            linear-scan-allocate callee-saved caller-saved
            blocked repeat virtual-variables
            filter-blocks blocked-intervals skeleton parameter delegate name coercion
            tensor-loop loop-details loop-setup loop-increment body dimension-hint
            term indexer lookup index type subst code convert-type assemble build-list package-return-content
            jit iterator step operand insert-intermediate
            is-pointer? need-conversion? code-needs-intermediate? call-needs-intermediate?
            force-parameters shl shr sign-extend-ax div mod
            test-zero ensure-default-strides unary-extract mutating-code functional-code decompose-value
            decompose-arg delegate-fun generate-return-code
            make-function make-native-function native-call make-constant-function native-const
            scm-eol scm-cons scm-gc-malloc-pointerless scm-gc-malloc operations)
  #:re-export (min max to-type + - && || ! != ~ & | ^ << >> % =0 !=0 conj)
  #:export-syntax (define-jit-method define-operator-mapping pass-parameters dim))

(define ctx (make <context>))


(define-method (native-type (i <real>) . args); TODO: remove this when floating point support is ready
  (if (every real? args)
      <obj>
      (apply native-type (sort-by-pred (cons i args) real?))))

(define (replace-variables allocation cmd temporary)
  "Replace variables with registers and add spill code if necessary"
  (let* [(location         (cut assq-ref allocation <>))
         (primary-argument (first-argument cmd))
         (primary-location (location primary-argument))]
    ; cases requiring more than one temporary variable are not handled at the moment
    (if (is-a? primary-location <address>)
      (let [(register (to-type (typecode primary-argument) temporary))]
        (compact (and (memv primary-argument (input cmd)) (MOV register primary-location))
                 (substitute-variables cmd (assq-set allocation primary-argument temporary))
                 (and (memv primary-argument (output cmd)) (MOV primary-location register))))
      (let [(spilled-pointer (filter (compose (cut is-a? <> <address>) location) (get-ptr-args cmd)))]
        ; assumption: (get-ptr-args cmd) only returns zero or one pointer argument requiring a temporary variable
        (attach (map (compose (cut MOV temporary <>) location) spilled-pointer)
                (substitute-variables cmd (fold (lambda (var alist) (assq-set alist var temporary)) allocation spilled-pointer)))))))

(define (adjust-stack-pointer offset prog)
  "Adjust stack pointer offset at beginning and end of program"
  (append (list (SUB RSP offset)) (all-but-last prog) (list (ADD RSP offset) (RET))))

(define (number-spilled-variables allocation stack-parameters)
  "Count the number of spilled variables"
  (length (difference (unallocated-variables allocation) stack-parameters)))

(define (temporary-variables prog)
  "Allocate temporary variable for each instruction which has a variable as first argument"
  (map (lambda (cmd) (let [(arg (first-argument cmd))]
         (or (and (not (null? (get-ptr-args cmd))) (var <long>))
             (and (is-a? arg <var>) (var (typecode arg))))))
       prog))

(define (unit-intervals vars)
  "Generate intervals of length one for each temporary variable"
  (filter car (map (lambda (var index) (cons var (cons index index))) vars (iota (length vars)))))

(define (temporary-registers allocation variables)
  "Look up register for each temporary variable given the result of a register allocation"
  (map (cut assq-ref allocation <>) variables))

(define (register-parameter-locations parameters)
  "Create an association list with the initial parameter locations"
  (map cons parameters (list RDI RSI RDX RCX R8 R9)))

(define (stack-parameter-locations parameters offset)
  "Determine initial locations of stack parameters"
  (map (lambda (parameter index) (cons parameter (ptr <long> RSP index)))
       parameters
       (iota (length parameters) (+ 8 offset) 8)))

(define (parameter-locations parameters offset)
  "return association list with default locations for the method parameters"
  (let [(register-parameters (register-parameters parameters))
        (stack-parameters    (stack-parameters parameters))]
    (append (register-parameter-locations register-parameters)
            (stack-parameter-locations stack-parameters offset))))

(define (add-stack-parameter-information allocation stack-parameter-locations)
   "Add the stack location for stack parameters which do not have a register allocated"
   (map (lambda (variable location) (cons variable (or location (assq-ref stack-parameter-locations variable))))
        (map car allocation)
        (map cdr allocation)))

(define (need-to-copy-first initial targets a b)
  "Check whether parameter A needs to be copied before B given INITIAL and TARGETS locations"
  (eq? (assq-ref initial a) (assq-ref targets b)))

(define (move-variable-content variable source destination)
  "move VARIABLE content from SOURCE to DESTINATION unless source and destination are the same"
  (let [(adapt (cut to-type (typecode variable) <>))]
    (if (or (not destination) (equal? source destination)) '() (MOV (adapt destination) (adapt source)))))

(define (update-parameter-locations parameters locations offset)
  "Generate the required code to update the parameter locations according to the register allocation"
  (let* [(initial            (parameter-locations parameters offset))
         (ordered-parameters (partial-sort parameters (cut need-to-copy-first initial locations <...>)))]
    (filter (compose not null?)
      (map (lambda (parameter)
             (move-variable-content parameter
                                    (assq-ref initial parameter)
                                    (assq-ref locations parameter)))
           ordered-parameters))))

(define (place-result-variable results locations code)
  "add code for placing result variable in register RAX if required"
  (filter (compose not null?)
          (attach (append (all-but-last code)
                          (map (lambda (result) (move-variable-content result (assq-ref locations result) RAX)) results))
                  (RET))))

; RSP is not included because it is used as a stack pointer
; RBP is not included because it may be used as a frame pointer
(define default-registers (list RAX RCX RDX RSI RDI R10 R11 R9 R8 R12 R13 R14 R15 RBX RBP))
(define callee-saved (list RBX RBP RSP R12 R13 R14 R15))
(define caller-saved (list RAX RCX RDX RSI RDI R10 R11 R9 R8))
(define parameter-registers (list RDI RSI RDX RCX R8 R9))

(define (used-callee-saved allocation)
   "Return the list of callee saved registers in use"
   (delete-duplicates (lset-intersection eq? (apply compact (map cdr allocation)) callee-saved)))

(define (backup-registers registers code)
  "Store register content on stack and restore it after executing the code"
  (append (map (cut PUSH <>) registers) (all-but-last code) (map (cut POP <>) (reverse registers)) (list (RET))))

(define* (linear-scan-allocate prog #:key (registers default-registers) (parameters '()) (blocked '()) (results '()))
  "Linear scan register allocation for a given program"
  (let* [(live                 (live-analysis prog results))
         (temp-vars            (temporary-variables prog))
         (intervals            (append (live-intervals live (variables prog))
                                       (unit-intervals temp-vars)))
         (predefined-registers (register-parameter-locations (register-parameters parameters)))
         (parameters-to-move   (blocked-predefined predefined-registers intervals blocked))
         (remaining-predefines (non-blocked-predefined predefined-registers parameters-to-move))
         (stack-parameters     (stack-parameters parameters))
         (colors               (linear-scan-coloring intervals registers remaining-predefines blocked))
         (callee-saved         (used-callee-saved colors))
         (stack-offset         (* 8 (1+ (number-spilled-variables colors stack-parameters))))
         (parameter-offset     (+ stack-offset (* 8 (length callee-saved))))
         (stack-locations      (stack-parameter-locations stack-parameters parameter-offset))
         (allocation           (add-stack-parameter-information colors stack-locations))
         (temporaries          (temporary-registers allocation temp-vars))
         (locations            (add-spill-information allocation 8 8))]
    (backup-registers callee-saved
      (adjust-stack-pointer stack-offset
        (place-result-variable results locations
          (append (update-parameter-locations parameters locations parameter-offset)
                  (append-map (cut replace-variables locations <...>) prog temporaries)))))))

(define (register-parameters parameters)
   "Return the parameters which are stored in registers according to the x86 ABI"
   (take-up-to parameters 6))

(define (stack-parameters parameters)
   "Return the parameters which are stored on the stack according to the x86 ABI"
   (drop-up-to parameters 6))

(define* (virtual-variables results parameters instructions #:key (registers default-registers))
  (linear-scan-allocate (flatten-code (relabel (filter-blocks instructions)))
                        #:registers registers
                        #:parameters parameters
                        #:results results
                        #:blocked (blocked-intervals instructions)))

(define (repeat start end . body)
  (let [(i (var (typecode end)))]
    (list (MOV i start) 'begin (CMP i end) (JE 'end) (INC i) body (JMP 'begin) 'end)))

(define-class <block> ()
  (reg  #:init-keyword #:reg  #:getter get-reg)
  (code #:init-keyword #:code #:getter get-code))
(define-method (blocked (reg <register>) . body) (make <block> #:reg reg #:code body))
(define-method (blocked (lst <null>) . body) body)
(define-method (blocked (lst <pair>) . body) (blocked (car lst) (apply blocked (cdr lst) body)))
(define (filter-blocks prog)
  (cond
    ((is-a? prog <block>) (filter-blocks (get-code prog)))
    ((list? prog)         (map filter-blocks prog))
    (else                 prog)))
(define ((bump-interval offset) interval)
  (cons (car interval) (cons (+ (cadr interval) offset) (+ (cddr interval) offset))))
(define code-length (compose length flatten-code filter-blocks))
(define (blocked-intervals prog)
  (cond
    ((is-a? prog <block>) (cons (cons (get-reg prog) (cons 0 (1- (code-length (get-code prog)))))
                            (blocked-intervals (get-code prog))))
    ((pair? prog) (append (blocked-intervals (car prog))
                    (map (bump-interval (code-length (list (car prog))))
                         (blocked-intervals (cdr prog)))))
    (else '())))

(define (sign-extend-ax size) (case size ((1) (CBW)) ((2) (CWD)) ((4) (CDQ)) ((8) (CQO))))
(define (div/mod-prepare-signed r a)
  (list (MOV (to-type (typecode r) RAX) a) (sign-extend-ax (size-of r))))
(define (div/mod-prepare-unsigned r a)
  (if (eqv? 1 (size-of r)) (list (MOVZX AX a)) (list (MOV (to-type (typecode r) RAX) a) (MOV (to-type (typecode r) RDX) 0))))
(define (div/mod-signed r a b) (attach (div/mod-prepare-signed r a) (IDIV b)))
(define (div/mod-unsigned r a b) (attach (div/mod-prepare-unsigned r a) (DIV b)))
(define (div/mod-block-registers r . code) (blocked RAX (if (eqv? 1 (size-of r)) code (blocked RDX code))))
(define (div/mod r a b . finalise) (div/mod-block-registers r ((if (signed? r) div/mod-signed div/mod-unsigned) r a b) finalise))
(define (div r a b) (div/mod r a b (MOV r (to-type (typecode r) RAX))))
(define (mod r a b) (div/mod r a b (if (eqv? 1 (size-of r)) (list (MOV AL AH) (MOV r AL)) (MOV r DX))))

(define-method (signed? (x <var>)) (signed? (typecode x)))
(define-method (signed? (x <ptr>)) (signed? (typecode x)))
(define (shx r x shift-signed shift-unsigned)
  (blocked RCX (mov-unsigned CL x) ((if (signed? r) shift-signed shift-unsigned) r CL)))
(define (shl r x) (shx r x SAL SHL))
(define (shr r x) (shx r x SAR SHR))
(define-method (test (a <var>)) (list (TEST a a)))
(define-method (test (a <ptr>))
  (let [(intermediate (var (typecode a)))]
    (list (MOV intermediate a) (test intermediate))))
(define (test-zero r a) (attach (test a) (SETE r)))
(define (test-non-zero r a) (attach (test a) (SETNE r)))
(define ((binary-bool op) a b)
  (let [(intermediate (var <byte>))]
    (attach (append (test-non-zero a a) (test-non-zero intermediate b)) (op a intermediate))))
(define bool-and (binary-bool AND))
(define bool-or  (binary-bool OR))

(define-method (cmp a b) (list (CMP a b)))
(define-method (cmp (a <ptr>) (b <ptr>))
  (let [(intermediate (var (typecode a)))]
    (cons (MOV intermediate a) (cmp intermediate b))))
(define ((cmp-setxx set-signed set-unsigned) out a b)
  (let [(set (if (or (signed? a) (signed? b)) set-signed set-unsigned))]
    (attach (cmp a b) (set out))))
(define cmp-equal         (cmp-setxx SETE   SETE  ))
(define cmp-not-equal     (cmp-setxx SETNE  SETNE ))
(define cmp-lower-than    (cmp-setxx SETL   SETB  ))
(define cmp-lower-equal   (cmp-setxx SETLE  SETBE ))
(define cmp-greater-than  (cmp-setxx SETNLE SETNBE))
(define cmp-greater-equal (cmp-setxx SETNL  SETNB ))

(define ((cmp-cmovxx set-signed set-unsigned jmp-signed jmp-unsigned) r a b)
  (if (eqv? 1 (size-of r))
    (append (mov r a) (cmp r b) (list ((if (signed? r) jmp-signed jmp-unsigned) 'skip)) (mov r b) (list 'skip))
    (append (mov r a) (cmp r b) (list ((if (signed? r) set-signed set-unsigned) r b)))))
(define minor (cmp-cmovxx CMOVNLE CMOVNBE JL   JB  ))
(define major (cmp-cmovxx CMOVL   CMOVB   JNLE JNBE))

(define-method (skeleton (self <meta<element>>)) (make self #:value (var self)))
(define-method (skeleton (self <meta<sequence<>>>))
  (let [(slice (skeleton (project self)))]
    (make self
          #:value   (value slice)
          #:shape   (cons (var <long>) (shape   slice))
          #:strides (cons (var <long>) (strides slice)))))

(define-class <param> ()
  (delegate #:init-keyword #:delegate #:getter delegate))

(define-class <indexer> (<param>)
  (dimension #:init-keyword #:dimension #:getter dimension)
  (index     #:init-keyword #:index     #:getter index))
(define (indexer index delegate dimension)
  (make <indexer> #:dimension dimension #:index index #:delegate delegate))

(define-class <lookup> (<param>)
  (index    #:init-keyword #:index    #:getter index   )
  (stride   #:init-keyword #:stride   #:getter stride  ))
(define-method (lookup index delegate stride)
  (make <lookup> #:index index #:delegate delegate #:stride stride))
(define-method (lookup idx (obj <indexer>) stride)
  (indexer (index obj) (lookup idx (delegate obj) stride) (dimension obj)))

(define-class <function> (<param>)
  (coercion  #:init-keyword #:coercion  #:getter coercion)
  (name      #:init-keyword #:name      #:getter name)
  (term      #:init-keyword #:term      #:getter term))

(define-method (type (self <param>)) (typecode (delegate self)))
(define-method (type (self <indexer>)) (sequence (type (delegate self))))
(define-method (type (self <lookup>)) (type (delegate self)))
(define-method (type (self <function>))
  (apply (coercion self) (map type (delegate self))))

(define-method (typecode (self <param>)) (typecode (type self)))

(define-method (shape (self <indexer>)) (attach (shape (delegate self)) (dimension self)))
(define-method (shape (self <function>)) (argmax length (map shape (delegate self))))

(define-method (strides (self <indexer>)) (attach (strides (delegate self)) (stride (lookup self (index self)))))
(define-method (lookup (self <indexer>)) (lookup self (index self)))
(define-method (lookup (self <indexer>) (idx <var>)) (lookup (delegate self) idx))
(define-method (lookup (self <lookup>) (idx <var>)) (if (eq? (index self) idx) self (lookup (delegate self) idx)))
(define-method (stride (self <indexer>)) (stride (lookup self)))
(define-method (parameter (self <element>)) (make <param> #:delegate self))
(define-method (parameter (self <sequence<>>))
  (let [(idx (var <long>))]
    (indexer idx
             (lookup idx
                     (parameter (project self))
                     (parameter (make <long> #:value (stride self))))
             (parameter (make <long> #:value (dimension self))))))
(define-method (parameter (self <meta<element>>)) (parameter (skeleton self)))

(define-method (subst self candidate replacement) self)
(define-method (subst (self <indexer>) candidate replacement)
  (indexer (index self) (subst (delegate self) candidate replacement) (dimension self)))
(define-method (subst (self <lookup>) candidate replacement)
  (lookup (if (eq? (index self) candidate) replacement (index self))
          (subst (delegate self) candidate replacement)
          (stride self)))

(define-method (value (self <param>)) (value (delegate self)))
(define-method (value (self <indexer>)) (value (delegate self)))
(define-method (value (self <lookup>)) (value (delegate self)))

(define-method (rebase value (self <param>)) (parameter (rebase value (delegate self))))
(define-method (rebase value (self <indexer>))
  (indexer (index self) (rebase value (delegate self)) (dimension self)))
(define-method (rebase value (self <lookup>))
  (lookup (index self) (rebase value (delegate self)) (stride self)))

(define-method (project (self <indexer>))
  (project (delegate self) (index self)))
(define-method (project (self <indexer>) (idx <var>))
  (indexer (index self) (project (delegate self) idx) (dimension self)))

(define-method (project (self <lookup>) (idx <var>))
  (if (eq? (index self) idx)
      (delegate self)
      (lookup (index self) (project (delegate self) idx) (stride self))))

(define dimension-hint (make-object-property))

(define (element idx self)
  (set! (dimension-hint idx) (dimension self))
  (subst (delegate self) (index self) idx))

(define-method (get (self <param>) . args)
  "Use multiple indices to access elements"
  (if (null? args) self (fold-right element self args)))

(define-syntax dim
  (lambda (x)
    (syntax-case x ()
      ((dim expr) #'expr)
      ((dim indices ... index expr) #'(let [(index (var <long>))] (indexer index (dim indices ... expr) (dimension-hint index)))))))

(define-method (size-of (self <param>))
  (apply * (native-const <long> (size-of (typecode (type self)))) (shape self)))

(define-method (operand (a <element>)) (get a))
(define-method (operand (a <pointer<>>))
  (if (pointer-offset a)
      (ptr (typecode a) (get a) (pointer-offset a))
      (ptr (typecode a) (get a))))
(define-method (operand (a <param>)) (operand (delegate a)))

(define-class <loop-detail> ()
  (typecode #:init-keyword #:typecode #:getter typecode)
  (iterator #:init-keyword #:iterator #:getter iterator)
  (step     #:init-keyword #:step     #:getter step    )
  (stride   #:init-keyword #:stride   #:getter stride  )
  (base     #:init-keyword #:base     #:getter base    ))

(define-method (loop-setup (self <loop-detail>))
  (list (IMUL (step self) (value (stride self)) (size-of (typecode self)))
        (MOV (iterator self) (base self))))

(define-method (loop-increment (self <loop-detail>))
  (list (ADD (iterator self) (step self))))

(define-class <tensor-loop> ()
  (loop-details #:init-keyword #:loop-details #:getter loop-details)
  (body         #:init-keyword #:body         #:getter body        ))

(define-method (tensor-loop (self <lookup>) (idx <var>))
  (if (eq? idx (index self))
    (let* [(iterator    (var <long>))
           (step        (var <long>))
           (loop-detail (make <loop-detail> #:typecode (typecode self)
                                            #:iterator iterator
                                            #:step     step
                                            #:stride   (stride self)
                                            #:base     (value self)))]
      (make <tensor-loop> #:loop-details (list loop-detail)
                          #:body         (rebase iterator (delegate self))))
    (let [(t (tensor-loop (delegate self) idx))]
      (make <tensor-loop> #:loop-details (loop-details t)
                          #:body         (lookup (index self) (body t) (stride self))))))

(define-method (tensor-loop (self <indexer>) (idx <var>))
  (let [(t (tensor-loop (delegate self) idx))]
    (make <tensor-loop> #:loop-details (loop-details t)
                        #:body         (indexer (index self) (body t) (dimension self)))))

(define-method (tensor-loop (self <indexer>))
  (tensor-loop (delegate self) (index self)))

(define-method (tensor-loop (self <function>) . idx)
  (let* [(arguments (map (cut apply tensor-loop <> idx) (delegate self)))
         (details   (append-map loop-details arguments))
         (bodies    (map body arguments))]
    (make <tensor-loop> #:loop-details details #:body (apply (name self) bodies))))

(define-method (tensor-loop (self <param>) . idx)
  (make <tensor-loop> #:loop-details '() #:body self))

(define (insert-intermediate value intermediate fun)
  (append (code intermediate value) (fun intermediate)))

(define-method (code (a <element>) (b <element>)) ((to-type (typecode a) (typecode b)) (parameter a) (list (parameter b))))
(define-method (code (a <element>) (b <integer>)) (list (MOV (operand a) b)))

(define-method (code (a <pointer<>>) (b <pointer<>>))
  (insert-intermediate b (skeleton (typecode a)) (cut code a <>)))
(define-method (code (a <param>) (b <param>)) (code (delegate a) (delegate b)))
(define-method (code (a <indexer>) (b <param>))
  (let [(dest   (tensor-loop a))
        (source (tensor-loop b))]
    (append (append-map loop-setup (loop-details dest))
            (append-map loop-setup (loop-details source))
            (repeat 0
                    (value (dimension a))
                    (code (body dest) (body source))
                    (append-map loop-increment (loop-details dest))
                    (append-map loop-increment (loop-details source))))))
(define-method (code (out <element>) (fun <function>))
  (if (need-conversion? (typecode out) (type fun))
    (insert-intermediate fun (skeleton (type fun)) (cut code out <>))
    ((term fun) (parameter out))))
(define-method (code (out <pointer<>>) (fun <function>))
  (insert-intermediate fun (skeleton (typecode out)) (cut code out <>)))
(define-method (code (out <param>) (fun <function>)) (code (delegate out) fun))
(define-method (code (out <param>) (value <integer>)) (code out (native-const (type out) value)))

; decompose parameters into elementary native types
(define-method (content (type <meta<element>>) (self <param>)) (map parameter (content type (delegate self))))
(define-method (content (type <meta<scalar>>) (self <function>)) (list self))
(define-method (content (type <meta<composite>>) (self <function>)) (delegate self))
(define-method (content (type <meta<sequence<>>>) (self <param>))
  (cons (dimension self) (cons (stride self) (content (project type) (project self)))))

(define (is-pointer? value) (and (delegate value) (is-a? (delegate value) <pointer<>>)))
(define-method (need-conversion? target type) (not (eq? target type)))
(define-method (need-conversion? (target <meta<int<>>>) (type <meta<int<>>>))
  (not (eqv? (size-of target) (size-of type))))
(define-method (need-conversion? (target <meta<bool>>) (type <meta<int<>>>))
  (not (eqv? (size-of target) (size-of type))))
(define-method (need-conversion? (target <meta<int<>>>) (type <meta<bool>>))
  (not (eqv? (size-of target) (size-of type))))
(define (code-needs-intermediate? t value) (or (is-a? value <function>) (need-conversion? t (type value))))
(define (call-needs-intermediate? t value) (or (is-pointer? value) (code-needs-intermediate? t value)))
(define-method (force-parameters (targets <list>) args predicate fun)
  (let* [(mask          (map predicate targets args))
         (intermediates (map-select mask (compose parameter car list) (compose cadr list) targets args))
         (preamble      (concatenate (map-select mask code (const '()) intermediates args)))]
    (attach preamble (apply fun intermediates))))
(define-method (force-parameters target args predicate fun)
  (force-parameters (make-list (length args) target) args predicate fun))

(define (operation-code target op out args)
  "Adapter for nested expressions"
  (force-parameters target args code-needs-intermediate?
    (lambda intermediates
      (apply op (operand out) (map operand intermediates)))))
(define ((functional-code op) out args)
  "Adapter for machine code without side effects on its arguments"
  (operation-code (reduce coerce #f (map type args)) op out args))
(define ((mutating-code op) out args)
  "Adapter for machine code overwriting its first argument"
  (insert-intermediate (car args) out (cut operation-code (type out) op <> (cdr args))))
(define ((unary-extract op) out args)
  "Adapter for machine code to extract part of a composite value"
  (code (delegate out) (apply op (map delegate args))))

(define-macro (define-operator-mapping name arity type fun)
  (let [(header (typed-header (symbol-list arity) type))]
    `(define-method (,name ,@header) ,fun)))

(define-operator-mapping -   1 <meta<int<>>> (mutating-code   NEG              ))
(define-method (- (z <integer>) (a <meta<int<>>>)) (mutating-code NEG))
(define-operator-mapping ~   1 <meta<int<>>> (mutating-code   NOT              ))
(define-operator-mapping =0  1 <meta<int<>>> (functional-code test-zero        ))
(define-operator-mapping !=0 1 <meta<int<>>> (functional-code test-non-zero    ))
(define-operator-mapping !   1 <meta<bool>>  (functional-code test-zero        ))
(define-operator-mapping +   2 <meta<int<>>> (mutating-code   ADD              ))
(define-operator-mapping -   2 <meta<int<>>> (mutating-code   SUB              ))
(define-operator-mapping *   2 <meta<int<>>> (mutating-code   IMUL             ))
(define-operator-mapping /   2 <meta<int<>>> (functional-code div              ))
(define-operator-mapping %   2 <meta<int<>>> (functional-code mod              ))
(define-operator-mapping <<  2 <meta<int<>>> (mutating-code   shl              ))
(define-operator-mapping >>  2 <meta<int<>>> (mutating-code   shr              ))
(define-operator-mapping &   2 <meta<int<>>> (mutating-code   AND              ))
(define-operator-mapping |   2 <meta<int<>>> (mutating-code   OR               ))
(define-operator-mapping ^   2 <meta<int<>>> (mutating-code   XOR              ))
(define-operator-mapping &&  2 <meta<bool>>  (mutating-code   bool-and         ))
(define-operator-mapping ||  2 <meta<bool>>  (mutating-code   bool-or          ))
(define-operator-mapping =   2 <meta<int<>>> (functional-code cmp-equal        ))
(define-operator-mapping !=  2 <meta<int<>>> (functional-code cmp-not-equal    ))
(define-operator-mapping <   2 <meta<int<>>> (functional-code cmp-lower-than   ))
(define-operator-mapping <=  2 <meta<int<>>> (functional-code cmp-lower-equal  ))
(define-operator-mapping >   2 <meta<int<>>> (functional-code cmp-greater-than ))
(define-operator-mapping >=  2 <meta<int<>>> (functional-code cmp-greater-equal))
(define-operator-mapping min 2 <meta<int<>>> (functional-code minor            ))
(define-operator-mapping max 2 <meta<int<>>> (functional-code major            ))

(define-operator-mapping -   1 <meta<element>> (native-fun obj-negate    ))
(define-method (- (z <integer>) (a <meta<element>>)) (native-fun obj-negate))
(define-operator-mapping ~   1 <meta<element>> (native-fun scm-lognot    ))
(define-operator-mapping =0  1 <meta<element>> (native-fun obj-zero-p    ))
(define-operator-mapping !=0 1 <meta<element>> (native-fun obj-nonzero-p ))
(define-operator-mapping !   1 <meta<element>> (native-fun obj-not       ))
(define-operator-mapping +   2 <meta<element>> (native-fun scm-sum       ))
(define-operator-mapping -   2 <meta<element>> (native-fun scm-difference))
(define-operator-mapping *   2 <meta<element>> (native-fun scm-product   ))
(define-operator-mapping /   2 <meta<element>> (native-fun scm-divide    ))
(define-operator-mapping %   2 <meta<element>> (native-fun scm-remainder ))
(define-operator-mapping <<  2 <meta<element>> (native-fun scm-ash       ))
(define-operator-mapping >>  2 <meta<element>> (native-fun obj-shr       ))
(define-operator-mapping &   2 <meta<element>> (native-fun scm-logand    ))
(define-operator-mapping |   2 <meta<element>> (native-fun scm-logior    ))
(define-operator-mapping ^   2 <meta<element>> (native-fun scm-logxor    ))
(define-operator-mapping &&  2 <meta<element>> (native-fun obj-and       ))
(define-operator-mapping ||  2 <meta<element>> (native-fun obj-or        ))
(define-operator-mapping =   2 <meta<element>> (native-fun obj-equal-p   ))
(define-operator-mapping !=  2 <meta<element>> (native-fun obj-nequal-p  ))
(define-operator-mapping <   2 <meta<element>> (native-fun obj-less-p    ))
(define-operator-mapping <=  2 <meta<element>> (native-fun obj-leq-p     ))
(define-operator-mapping >   2 <meta<element>> (native-fun obj-gr-p      ))
(define-operator-mapping >=  2 <meta<element>> (native-fun obj-geq-p     ))
(define-operator-mapping min 2 <meta<element>> (native-fun scm-min       ))
(define-operator-mapping max 2 <meta<element>> (native-fun scm-max       ))

(define-method (decompose-value (target <meta<scalar>>) self) self)

(define-method (delegate-op (target <meta<scalar>>) (intermediate <meta<scalar>>) name out args)
  ((apply name (map type args)) out args))
(define-method (delegate-op (target <meta<sequence<>>>) (intermediate <meta<sequence<>>>) name out args)
  ((apply name (map type args)) out args))
(define-method (delegate-op target intermediate name out args)
  (let [(result (apply name (map (lambda (arg) (decompose-value (type arg) arg)) args)))]
    (append-map code (content (type out) out) (content (type result) result))))
(define (delegate-fun name)
  (lambda (out args) (delegate-op (type out) (reduce coerce #f (map type args)) name out args)))

(define (make-function name coercion fun args)
  (make <function> #:delegate args
                   #:coercion coercion
                   #:name     name
                   #:term     (lambda (out) (fun out args))))

(define-method (type (self <function>))
  (apply (coercion self) (map type (delegate self))))

(define-macro (n-ary-base name arity coercion fun)
  (let* [(args   (symbol-list arity))
         (header (typed-header args '<param>))]
    `(define-method (,name ,@header) (make-function ,name ,coercion ,fun (list ,@args)))))

(define (content-vars args) (map get (append-map content (map class-of args) args)))

(define (assemble return-args args instructions)
  "Determine result variables, argument variables, and instructions"
  (list (content-vars return-args) (content-vars args) (attach instructions (RET))))

(define (build-list . args)
  "Generate code to package ARGS in a Scheme list"
  (fold-right scm-cons scm-eol args))

(define (package-return-content value)
  "Generate code to package parameter VALUE in a Scheme list"
  (apply build-list (content (type value) value)))

(define-method (construct-value result-type retval expr) '())
(define-method (construct-value (result-type <meta<sequence<>>>) retval expr)
  (let [(malloc (if (pointerless? result-type) scm-gc-malloc-pointerless scm-gc-malloc))]
    (append (append-map code (shape retval) (shape expr))
            (code (last (content result-type retval)) (malloc (size-of retval)))
            (append-map code (strides retval) (default-strides (shape retval))))))

(define (generate-return-code args intermediate expr)
  (let [(retval (skeleton <obj>))]
    (list (list retval)
          args
          (append (construct-value (type intermediate) intermediate expr)
                  (code intermediate expr)
                  (code (parameter retval) (package-return-content intermediate))))))

(define (jit context classes proc)
  (let* [(args         (map skeleton classes))
         (expr         (apply proc (map parameter args)))
         (result-type  (type expr))
         (intermediate (parameter result-type))
         (types        (map class-of args))
         (result       (generate-return-code args intermediate expr))
         (instructions (asm context
                            <ulong>
                            (map typecode (content-vars args))
                            (apply virtual-variables (apply assemble result))))
         (fun          (lambda header (apply instructions (append-map unbuild types header))))]
    (lambda args (build result-type (address->scm (apply fun args))))))

(define-macro (define-jit-dispatch name arity delegate)
  (let* [(args   (symbol-list arity))
         (header (typed-header args '<element>))]
    `(define-method (,name ,@header)
       (let [(f (jit ctx (map class-of (list ,@args)) ,delegate))]
         (add-method! ,name
                      (make <method>
                            #:specializers (map class-of (list ,@args))
                            #:procedure (lambda args (apply f (map get args))))))
       (,name ,@args))))

(define-macro (define-nary-collect name arity)
  (let* [(args   (symbol-list arity))
         (header (cons (list (car args) '<element>) (cdr args)))]; TODO: extract and test
    (cons 'begin
          (map
            (lambda (i)
              `(define-method (,name ,@(cycle-times header i))
                (apply ,name (map wrap (list ,@(cycle-times args i))))))
            (iota arity)))))

(define operations '())

(define-syntax-rule (define-jit-method coercion name arity)
  (begin (set! operations (cons (quote name) operations))
         (n-ary-base name arity coercion (delegate-fun name))
         (define-nary-collect name arity)
         (define-jit-dispatch name arity name)))

; various type class conversions
(define-method (convert-type (target <meta<element>>) (self <meta<element>>)) target)
(define-method (convert-type (target <meta<element>>) (self <meta<sequence<>>>)) (multiarray target (dimensions self)))
(define-method (to-bool a) (convert-type <bool> a))
(define-method (to-bool a b) (coerce (to-bool a) (to-bool b)))

; define unary and binary operations
(define-method (+ (a <param>)) a)
(define-method (+ (a <element>)) a)
(define-method (* (a <param>)) a)
(define-method (* (a <element>)) a)
(define-jit-dispatch duplicate 1 identity)
(define-jit-method identity -   1)
(define-jit-method identity ~   1)
(define-jit-method to-bool  =0  1)
(define-jit-method to-bool  !=0 1)
(define-jit-method to-bool  !   1)
(define-jit-method coerce   +   2)
(define-jit-method coerce   -   2)
(define-jit-method coerce   *   2)
(define-jit-method coerce   /   2)
(define-jit-method coerce   %   2)
(define-jit-method coerce   <<  2)
(define-jit-method coerce   >>  2)
(define-jit-method coerce   &   2)
(define-jit-method coerce   |   2)
(define-jit-method coerce   ^   2)
(define-jit-method coerce   &&  2)
(define-jit-method coerce   ||  2)
(define-jit-method to-bool  =   2)
(define-jit-method to-bool  !=  2)
(define-jit-method to-bool  <   2)
(define-jit-method to-bool  <=  2)
(define-jit-method to-bool  >   2)
(define-jit-method to-bool  >=  2)
(define-jit-method coerce   min 2)
(define-jit-method coerce   max 2)

(define-method (to-type (target <meta<ubyte>>) (source <meta<obj>>  )) (native-fun scm-to-uint8   ))
(define-method (to-type (target <meta<byte>> ) (source <meta<obj>>  )) (native-fun scm-to-int8    ))
(define-method (to-type (target <meta<usint>>) (source <meta<obj>>  )) (native-fun scm-to-uint16  ))
(define-method (to-type (target <meta<sint>> ) (source <meta<obj>>  )) (native-fun scm-to-int16   ))
(define-method (to-type (target <meta<uint>> ) (source <meta<obj>>  )) (native-fun scm-to-uint32  ))
(define-method (to-type (target <meta<int>>  ) (source <meta<obj>>  )) (native-fun scm-to-int32   ))
(define-method (to-type (target <meta<ulong>>) (source <meta<obj>>  )) (native-fun scm-to-uint64  ))
(define-method (to-type (target <meta<long>> ) (source <meta<obj>>  )) (native-fun scm-to-int64   ))
(define-method (to-type (target <meta<int<>>>) (source <meta<int<>>>)) (functional-code mov       ))
(define-method (to-type (target <meta<int<>>>) (source <meta<bool>> )) (functional-code mov       ))
(define-method (to-type (target <meta<bool>> ) (source <meta<bool>> )) (functional-code mov       ))
(define-method (to-type (target <meta<bool>> ) (source <meta<int<>>>)) (functional-code mov       ))
(define-method (to-type (target <meta<bool>> ) (source <meta<obj>>  )) (native-fun scm-to-bool    ))
(define-method (to-type (target <meta<obj>>  ) (source <meta<obj>>  )) (functional-code mov       ))
(define-method (to-type (target <meta<obj>>  ) (source <meta<ubyte>>)) (native-fun scm-from-uint8 ))
(define-method (to-type (target <meta<obj>>  ) (source <meta<byte>> )) (native-fun scm-from-int8  ))
(define-method (to-type (target <meta<obj>>  ) (source <meta<usint>>)) (native-fun scm-from-uint16))
(define-method (to-type (target <meta<obj>>  ) (source <meta<sint>> )) (native-fun scm-from-int16 ))
(define-method (to-type (target <meta<obj>>  ) (source <meta<uint>> )) (native-fun scm-from-uint32))
(define-method (to-type (target <meta<obj>>  ) (source <meta<int>>  )) (native-fun scm-from-int32 ))
(define-method (to-type (target <meta<obj>>  ) (source <meta<ulong>>)) (native-fun scm-from-uint64))
(define-method (to-type (target <meta<obj>>  ) (source <meta<long>> )) (native-fun scm-from-int64 ))
(define-method (to-type (target <meta<obj>>  ) (source <meta<bool>> )) (native-fun obj-from-bool  ))
(define-method (to-type (target <meta<composite>>) (source <meta<composite>>))
  (lambda (out args)
    (append-map
      (lambda (channel) (code (channel (delegate out)) (channel (delegate (car args)))))
      (components source))))

(define-method (to-type (target <meta<element>>) (a <param>))
  (let [(to-target  (cut to-type target <>))
        (coercion   (cut convert-type target <>))]
    (make-function to-target coercion (delegate-fun to-target) (list a))))
(define-method (to-type (target <meta<element>>) (self <element>))
  (let [(f (jit ctx (list (class-of self)) (cut to-type target <>)))]
    (add-method! to-type
                 (make <method>
                       #:specializers (map class-of (list target self))
                       #:procedure (lambda (target self) (f (get self)))))
    (to-type target self)))

(define (ensure-default-strides img)
  "Create a duplicate of the array unless it is compact"
  (if (equal? (strides img) (default-strides (shape img))) img (duplicate img)))

(define-syntax-rule (pass-parameters parameters body ...)
  (let [(first-six-parameters (take-up-to parameters 6))
        (remaining-parameters (drop-up-to parameters 6))]
    (append (map (lambda (register parameter)
                   (MOV (to-type (native-equivalent (type parameter)) register) (get (delegate parameter))))
                 parameter-registers
                 first-six-parameters)
            (map (lambda (parameter) (PUSH (get (delegate parameter)))) remaining-parameters)
            (list body ...)
            (list (ADD RSP (* 8 (length remaining-parameters)))))))

(define* ((native-fun native) out args)
  (force-parameters (argument-types native) args call-needs-intermediate?
    (lambda intermediates
      (blocked caller-saved
        (pass-parameters intermediates
          (MOV RAX (function-pointer native))
          (CALL RAX)
          (MOV (get (delegate out)) (to-type (native-equivalent (return-type native)) RAX)))))))

(define (make-native-function native . args)
  (make-function make-native-function (const (return-type native)) (native-fun native) args))

(define (native-call return-type argument-types function-pointer)
  (cut make-native-function (make-native-method return-type argument-types function-pointer) <...>))

(define* ((native-data native) out args) (list (MOV (get (delegate out)) (get native))))

(define (make-constant-function native . args) (make-function make-constant-function (const (return-type native)) (native-data native) args))

(define (native-const type value) (make-constant-function (native-value type value)))

; Scheme list manipulation
(define main (dynamic-link))
(define scm-eol (native-const <obj> (scm->address '())))
(define scm-cons (native-call <obj> (list <obj> <obj>) (dynamic-func "scm_cons" main)))
(define scm-gc-malloc-pointerless (native-call <ulong> (list <ulong>) (dynamic-func "scm_gc_malloc_pointerless" main)))
(define scm-gc-malloc             (native-call <ulong> (list <ulong>) (dynamic-func "scm_gc_malloc"             main)))
