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
  #:use-module (aiscm expression)
  #:use-module (aiscm loop)
  #:use-module (aiscm compile)
  #:use-module (aiscm operation)
  #:use-module (aiscm method)
  #:export (virtual-variables
            assemble build-list package-return-content
            content-vars jit fill
            is-pointer? call-needs-intermediate?
            ensure-default-strides decompose-value
            decompose-arg delegate-fun generate-return-code
            make-native-function native-call
            scm-eol scm-cons scm-gc-malloc-pointerless scm-gc-malloc operations
            coerce-where)
  #:re-export (min max to-type + - * == && || ! != ~ & | ^ << >> % =0 !=0 lt le gt ge
               -= ~= abs= += *= <<= >>= &= |= ^= &&= ||= min= max=)
  #:export-syntax (define-jit-method pass-parameters))

(define ctx (make <context>))


(define* (virtual-variables results parameters instructions #:key (registers default-registers))
  (jit-compile (flatten-code (relabel (filter-blocks instructions)))
               #:registers registers
               #:parameters parameters
               #:results results
               #:blocked (blocked-intervals instructions)))

(define (is-pointer? value) (and (delegate value) (is-a? (delegate value) <pointer<>>)))
(define (call-needs-intermediate? t value) (or (is-pointer? value) (code-needs-intermediate? t value)))

(define-macro (define-cumulative name arity)
  (let* [(args   (symbol-list arity))
         (header (typed-header args '<param>))]
    `(define-method (,name ,@header) ((delegate-fun ,name) ,(car args) ,@args))))

(define-cumulative -=   1)
(define-cumulative ~=   1)
(define-cumulative abs= 1)
(define-cumulative <<=  1)
(define-cumulative >>=  1)
(define-cumulative +=   2)
(define-cumulative -=   2)
(define-cumulative *=   2)
(define-cumulative <<=  2)
(define-cumulative >>=  2)
(define-cumulative &=   2)
(define-cumulative |=   2)
(define-cumulative ^=   2)
(define-cumulative &&=  2)
(define-cumulative ||=  2)
(define-cumulative min= 2)
(define-cumulative max= 2)

(define-operator-mapping -     (<meta<element>>                ) (native-fun obj-negate    ))
(define-method (- (z <integer>) (a <meta<element>>)) (native-fun obj-negate))
(define-operator-mapping ~     (<meta<element>>                ) (native-fun scm-lognot    ))
(define-operator-mapping abs   (<meta<element>>                ) (native-fun scm-abs       ))
(define-operator-mapping =0    (<meta<element>>                ) (native-fun obj-zero-p    ))
(define-operator-mapping !=0   (<meta<element>>                ) (native-fun obj-nonzero-p ))
(define-operator-mapping !     (<meta<element>>                ) (native-fun obj-not       ))
(define-operator-mapping <<    (<meta<element>>                ) (native-fun obj-shl1      ))
(define-operator-mapping >>    (<meta<element>>                ) (native-fun obj-shr1      ))
(define-operator-mapping +     (<meta<element>> <meta<element>>) (native-fun scm-sum       ))
(define-operator-mapping -     (<meta<element>> <meta<element>>) (native-fun scm-difference))
(define-operator-mapping *     (<meta<element>> <meta<element>>) (native-fun scm-product   ))
(define-operator-mapping /     (<meta<element>> <meta<element>>) (native-fun scm-divide    ))
(define-operator-mapping %     (<meta<element>> <meta<element>>) (native-fun scm-remainder ))
(define-operator-mapping <<    (<meta<element>> <meta<element>>) (native-fun scm-ash       ))
(define-operator-mapping >>    (<meta<element>> <meta<element>>) (native-fun obj-shr       ))
(define-operator-mapping &     (<meta<element>> <meta<element>>) (native-fun scm-logand    ))
(define-operator-mapping |     (<meta<element>> <meta<element>>) (native-fun scm-logior    ))
(define-operator-mapping ^     (<meta<element>> <meta<element>>) (native-fun scm-logxor    ))
(define-operator-mapping &&    (<meta<element>> <meta<element>>) (native-fun obj-and       ))
(define-operator-mapping ||    (<meta<element>> <meta<element>>) (native-fun obj-or        ))
(define-operator-mapping ==    (<meta<element>> <meta<element>>) (native-fun obj-equal-p   ))
(define-operator-mapping !=    (<meta<element>> <meta<element>>) (native-fun obj-nequal-p  ))
(define-operator-mapping lt    (<meta<element>> <meta<element>>) (native-fun obj-less-p    ))
(define-operator-mapping le    (<meta<element>> <meta<element>>) (native-fun obj-leq-p     ))
(define-operator-mapping gt    (<meta<element>> <meta<element>>) (native-fun obj-gr-p      ))
(define-operator-mapping ge    (<meta<element>> <meta<element>>) (native-fun obj-geq-p     ))
(define-operator-mapping min   (<meta<element>> <meta<element>>) (native-fun scm-min       ))
(define-operator-mapping max   (<meta<element>> <meta<element>>) (native-fun scm-max       ))
(define-operator-mapping where (<meta<element>> <meta<element>> <meta<element>>) (native-fun obj-where     ))

(define-macro (define-object-cumulative name basis)
  `(define-method (,name (a <meta<obj>>) (b <meta<obj>>))
    (lambda (out . args) (duplicate out (apply ,basis args)))))

(define-object-cumulative +=   +  )
(define-object-cumulative *=   *  )
(define-object-cumulative max= max)
(define-object-cumulative min= min)

(define-method (decompose-value (target <meta<scalar>>) self) self)

; ---------------------------------
(define-method (delegate-op (target <meta<scalar>>) (intermediate <meta<scalar>>) name out args)
  (apply (apply name (map type args)) out args))
(define-method (delegate-op (target <meta<sequence<>>>) (intermediate <meta<sequence<>>>) name out args)
  (apply (apply name (map type args)) out args))
(define-method (delegate-op (target <meta<element>>) (intermediate <meta<element>>) name out args)
  (if (any (cut is-a? <> <function>) args)
    (let [(intermediates (map (lambda (arg) (if (is-a? arg <function>) (parameter (type arg)) arg)) args))]
      (append (append-map (lambda (intermediate arg)
                            (if (eq? intermediate arg) '() (duplicate intermediate arg))) intermediates args)
              (delegate-op target intermediate name out intermediates)))
    (let [(result (apply name (map (lambda (arg) (decompose-value (type arg) arg)) args)))]
      (if (eq? out (car args)); hack for cumulative operations
        result
        (append-map duplicate (content (type out) out) (content (type result) result))))))
(define ((delegate-fun name) out . args)
  (delegate-op (type out) (reduce coerce #f (map type args)) name out args))
; ---------------------------------

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
    (append (append-map duplicate (shape retval) (shape expr))
            (duplicate (last (content result-type retval)) (malloc (size-of retval)))
            (append-map duplicate (strides retval) (default-strides (shape retval))))))

(define (generate-return-code args intermediate expr)
  (let [(retval (skeleton <obj>))]
    (list (list retval)
          args
          (append (construct-value (type intermediate) intermediate expr)
                  (duplicate intermediate expr)
                  (duplicate (parameter retval) (package-return-content intermediate))))))

(define (jit context classes proc)
  (let* [(args         (map skeleton classes))
         (parameters   (map parameter args))
         (expr         (apply proc parameters))
         (result-type  (type expr))
         (intermediate (parameter result-type))
         (result       (generate-return-code args intermediate expr))
         (commands     (apply virtual-variables (apply assemble result)))
         (instructions (asm context <ulong> (map typecode (content-vars args)) commands))
         (fun          (lambda header (apply instructions (append-map unbuild classes header))))]
    (lambda args (build result-type (address->scm (apply fun args))))))

(define-method (fill type shape value)
  (if (< (dimensions type) (length shape))
    (fill (multiarray type (length shape)) shape value)
    (let* [(result-type  (pointer type))
           (args         (list (skeleton result-type) (skeleton (typecode type))))
           (parameters   (map parameter args))
           (commands     (virtual-variables '() (content-vars args) (attach (apply duplicate parameters) (RET))))
           (instructions (asm ctx <null> (map typecode (content-vars args)) commands))
           (proc         (lambda args (apply instructions (append-map unbuild (list result-type (typecode type)) args))))]
      (add-method! fill
                   (make <method>
                         #:specializers (list (class-of type) (if (null? shape) <null> <list>) <top>)
                         #:procedure (lambda (type shape value)
                               (let [(result (make result-type #:shape shape))] (proc result value) (get (fetch result))))))
      (fill type shape value))))

(define-macro (define-jit-dispatch name arity delegate)
  "Compilation and caching of array operations"
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
  "Dispatch for n-ary operation with Scheme numerical types"
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

; ---------------------------------
(set! operations (cons '+ operations))

; here: build expression to resolve loops
; aiscm operation: map + to += and then to ADD for integers, (+ <int> <int>)
; TODO: use += <int> <int>, implement + <intrgb> <intrgb>, handle intermediates
(define ((delegate-plus-fun name) out . args) (apply (apply name (map type args)) out args))
(define-method (+ (a <param>) (b <param>)) (make-function + coerce (delegate-plus-fun +) (list a b)))
(define-method (+= (a <param>) (b <param>)) ((delegate-plus-fun +=) a a b))

(define-method (+ (a <meta<composite>>) (b <meta<element>>))
  (lambda (out . args)
    (let [(result (apply + (map (lambda (arg) (decompose-value (type arg) arg)) args)))]
      (append-map duplicate (content (type out) out) (content (type result) result)))))
(define-method (+ (a <meta<element>>) (b <meta<composite>>))
  (lambda (out . args)
    (let [(result (apply + (map (lambda (arg) (decompose-value (type arg) arg)) args)))]
      (append-map duplicate (content (type out) out) (content (type result) result)))))

(define-nary-collect + 2)
(define-jit-dispatch + 2 +)
; ---------------------------------

(define-method (to-bool a) (convert-type <bool> a))
(define-method (to-bool a b) (coerce (to-bool a) (to-bool b)))

(define (coerce-where m a b)
  "Coercion for selecting values using a boolean mask with 'where'"
  (convert-type (typecode (coerce a b)) (reduce coerce #f (list m a b))))

(define-jit-dispatch duplicate 1 identity)
(define-jit-method identity -   1)
(define-jit-method identity ~   1)
(define-jit-method identity abs 1)
(define-jit-method to-bool  =0  1)
(define-jit-method to-bool  !=0 1)
(define-jit-method to-bool  !   1)
(define-jit-method identity <<  1)
(define-jit-method identity >>  1)
;(define-jit-method coerce   +   2)
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
(define-jit-method to-bool  ==  2)
(define-jit-method to-bool  !=  2)
(define-jit-method to-bool  lt  2)
(define-jit-method to-bool  le  2)
(define-jit-method to-bool  gt  2)
(define-jit-method to-bool  ge  2)
(define-jit-method coerce   min 2)
(define-jit-method coerce   max 2)
(define-jit-method coerce-where where 3)

(define-method (to-type (target <meta<ubyte>>) (source <meta<obj>>  )) (native-fun scm-to-uint8   ))
(define-method (to-type (target <meta<byte>> ) (source <meta<obj>>  )) (native-fun scm-to-int8    ))
(define-method (to-type (target <meta<usint>>) (source <meta<obj>>  )) (native-fun scm-to-uint16  ))
(define-method (to-type (target <meta<sint>> ) (source <meta<obj>>  )) (native-fun scm-to-int16   ))
(define-method (to-type (target <meta<uint>> ) (source <meta<obj>>  )) (native-fun scm-to-uint32  ))
(define-method (to-type (target <meta<int>>  ) (source <meta<obj>>  )) (native-fun scm-to-int32   ))
(define-method (to-type (target <meta<ulong>>) (source <meta<obj>>  )) (native-fun scm-to-uint64  ))
(define-method (to-type (target <meta<long>> ) (source <meta<obj>>  )) (native-fun scm-to-int64   ))
(define-method (to-type (target <meta<int<>>>) (source <meta<int<>>>)) (functional-code identity mov))
(define-method (to-type (target <meta<int<>>>) (source <meta<bool>> )) (functional-code identity mov))
(define-method (to-type (target <meta<bool>> ) (source <meta<bool>> )) (functional-code identity mov))
(define-method (to-type (target <meta<bool>> ) (source <meta<int<>>>)) (functional-code identity mov))
(define-method (to-type (target <meta<bool>> ) (source <meta<obj>>  )) (native-fun scm-to-bool    ))
(define-method (to-type (target <meta<obj>>  ) (source <meta<obj>>  )) (functional-code identity mov))
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
  (lambda (out arg)
    (append-map
      (lambda (channel) (duplicate (channel (delegate out)) (channel (delegate arg))))
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

(define* ((native-fun native) out . args)
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

; Scheme list manipulation
(define main (dynamic-link))
(define scm-eol (native-const <obj> (scm->address '())))
(define scm-cons (native-call <obj> (list <obj> <obj>) (dynamic-func "scm_cons" main)))
(define scm-gc-malloc-pointerless (native-call <ulong> (list <ulong>) (dynamic-func "scm_gc_malloc_pointerless" main)))
(define scm-gc-malloc             (native-call <ulong> (list <ulong>) (dynamic-func "scm_gc_malloc"             main)))
