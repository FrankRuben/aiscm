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
(define-module (aiscm llvm)
  #:use-module (oop goops)
  #:use-module (ice-9 optargs)
  #:use-module (system foreign)
  #:use-module (aiscm util)
  #:export (<llvm> <meta<llvm>>
            <llvm-function> <meta<llvm-function>>
            <llvm-value> <meta<llvm-value>>
            make-constant make-llvm-module make-function llvm-dump
            function-ret llvm-func get-type llvm-compile function-load function-store function-param
            llvm-neg llvm-fneg llvm-not
            llvm-add llvm-fadd)
  #:re-export (destroy))

(load-extension "libguile-aiscm-llvm" "init_llvm")

(define-class* <llvm> <object> <meta<llvm>> <class>
               (llvm-module #:init-keyword #:llvm-module))

(define-method (initialize (self <llvm>) initargs)
  (next-method self (list #:llvm-module (make-llvm-module-base))))

(define (make-llvm-module) (make <llvm>))

(define-method (destroy (self <llvm>)) (llvm-module-destroy (slot-ref self 'llvm-module)))

(define-class* <llvm-function> <object> <meta<llvm-function>> <class>
               (module         #:init-keyword #:module        )
               (name           #:init-keyword #:name          )
               (return-type    #:init-keyword #:return-type   )
               (llvm-function  #:init-keyword #:llvm-function )
               (argument-types #:init-keyword #:argument-types))

(define-method (initialize (self <llvm-function>) initargs)
  (let-keywords initargs #f (module return-type name argument-types)
    (let* [(fun (make-llvm-function (slot-ref module 'llvm-module)
                                   return-type
                                   name
                                   argument-types))]
    (next-method self (list #:module         module
                            #:name           name
                            #:return-type    return-type
                            #:llvm-function  fun
                            #:argument-types argument-types)))))

(define (make-function module return-type name . argument-types)
  (make <llvm-function> #:module module
                        #:return-type return-type
                        #:name name
                        #:argument-types argument-types))

(define-method (destroy (self <llvm-function>)) (llvm-function-destroy (slot-ref self 'llvm-function)))

(define* (function-ret self #:optional (result #f))
  (let [(llvm-function (slot-ref self 'llvm-function))]
    (if result
      (llvm-function-return llvm-function (slot-ref result 'llvm-value))
      (llvm-function-return-void llvm-function))))

(define (llvm-compile self)
  (llvm-verify-module (slot-ref self 'llvm-module))
  (llvm-compile-module (slot-ref self 'llvm-module)))

(define (llvm-dump self) (llvm-dump-module (slot-ref self 'llvm-module)))

(define (llvm-func llvm fun)
  (let [(pointer (llvm-get-function-address (slot-ref llvm 'llvm-module) (slot-ref fun 'name)))]
    (pointer->procedure (slot-ref fun 'return-type) pointer (slot-ref fun 'argument-types))))

(define-class* <llvm-value> <object> <meta<llvm-value>> <class>
               (llvm-value #:init-keyword #:llvm-value))

(define (make-constant type value)
  "Create a constant LLVM value"
  (make <llvm-value> #:llvm-value (make-llvm-constant type value)))

(define (get-type value)
  "Query type of LLVM value"
  (llvm-get-type (slot-ref value 'llvm-value)))

(define (function-load self type address)
  "Generate code for reading value from memory"
  (make <llvm-value> #:llvm-value (llvm-build-load (slot-ref self 'llvm-function) type (slot-ref address 'llvm-value))))

(define (function-store self type value address)
  "Generate code for writing value to memory"
  (llvm-build-store (slot-ref self 'llvm-function) type (slot-ref value 'llvm-value) (slot-ref address 'llvm-value)))

(define (function-param self index)
  "Get value of INDEXth function parameter"
  (make <llvm-value> #:llvm-value (llvm-get-param (slot-ref self 'llvm-function) index)))

(define (llvm-neg self value)
  "Instruction to negate integer value"
  (make <llvm-value> #:llvm-value (llvm-build-neg (slot-ref self 'llvm-function)
                                                  (slot-ref value 'llvm-value))))

(define (llvm-fneg self value)
  "Instruction to negate floating-point value"
  (make <llvm-value> #:llvm-value (llvm-build-fneg (slot-ref self 'llvm-function)
                                                   (slot-ref value 'llvm-value))))

(define (llvm-not self value)
  "Bitwise not for integer value"
  (make <llvm-value> #:llvm-value (llvm-build-not (slot-ref self 'llvm-function)
                                                  (slot-ref value 'llvm-value))))

(define (llvm-add self value-a value-b)
  "Instruction to add two integer values"
  (make <llvm-value> #:llvm-value (llvm-build-add (slot-ref self 'llvm-function)
                                                  (slot-ref value-a 'llvm-value)
                                                  (slot-ref value-b 'llvm-value))))

(define (llvm-fadd self value-a value-b)
  "Instruction to add two floating-point values"
  (make <llvm-value> #:llvm-value (llvm-build-fadd (slot-ref self 'llvm-function)
                                                   (slot-ref value-a 'llvm-value)
                                                   (slot-ref value-b 'llvm-value))))