#|
  This file is a part of sxql project.
  Copyright (c) 2013 Eitarow Fukamachi (e.arrows@gmail.com)
|#

(in-package :cl-user)
(defpackage sxql
  (:use :cl
        :sxql.statement
        :sxql.clause)
  (:import-from :sxql.sql-type
                :sql-clause-list
                :yield
                :*use-placeholder*
                :*quote-character*)
  (:import-from :sxql.compile
                :sql-compile)
  (:import-from :sxql.operator
                :make-op
                :detect-and-convert)
  (:export :yield
           :sql-compile
           :*use-placeholder*
           :*quote-character*))
(in-package :sxql)

(cl-syntax:use-syntax :annot)

(defun expand-op (object)
  (if (and (listp object)
           (keywordp (car object)))
      `(make-op ,(car object) ,@(mapcar #'expand-op (cdr object)))
      object))

(defun expand-expression (expressions)
  (cond
    ((not (listp expressions)) expressions)
    ((and (symbolp (car expressions))
          (not (keywordp (car expressions))))
     expressions)
    (t (mapcar #'expand-op expressions))))

@export
(defmacro select (field &body clauses)
  (let ((clauses-g (gensym "CLAUSES")))
    `(let ((,clauses-g (list ,@clauses)))
       (apply #'make-statement :select ,(if (listp field)
                                            (if (and (symbolp (car field))
                                                     (not (keywordp (car field))))
                                                field
                                                `(list ,@(mapcar #'expand-op field)))
                                            `,field) ,clauses-g))))

@export
(defmacro insert-into (table &body clauses)
  (let ((clauses-g (gensym "CLAUSES")))
    `(let ((,clauses-g (list ,@clauses)))
       (apply #'make-statement :insert-into
              ,(expand-expression table)
              ,clauses-g))))

@export
(defmacro update (table &body clauses)
  `(make-statement :update
                   ,(expand-expression table) ,@clauses))

@export
(defmacro delete-from (table &body clauses)
  `(make-statement :delete-from
                   ,(expand-expression table) ,@clauses))

@export
(defmacro create-table (table column-definitions &body options)
  `(make-statement :create-table
                   ,(expand-expression table)
                   (list ,@(if column-definitions
                               (mapcar
                                (lambda (column)
                                  `(make-column-definition-clause ',(car column) ,@(cdr column)))
                                column-definitions)
                               nil))
                   ,@(if (and (null (cdr options))
                              (null (car options)))
                         nil
                         options)))

@export
(defmacro drop-table (table &key if-exists)
  `(make-statement :drop-table
                   ,(expand-expression table) :if-exists ,if-exists))

@export
(defun union-queries (&rest queries)
  (apply #'sxql.operator:make-op :union queries))

@export
(defun union-all-queries (&rest queries)
  (apply #'sxql.operator:make-op :union-all queries))

;;
;; Clauses

@export
(defmacro from (statement)
  `(make-clause :from ,(expand-op statement)))

@export
(defmacro where (expression)
  `(make-clause :where
                ,(if (and (listp expression)
                          (keywordp (car expression)))
                     (expand-op expression)
                     `,expression)))

@export
(defmacro order-by (&rest expressions)
  `(make-clause :order-by ,@(expand-expression expressions)))

@export
(defmacro group-by (&rest expressions)
  `(apply #'make-clause :group-by ',expressions))

@export
(defun limit (count1 &optional count2)
  (apply #'make-clause :limit `(,count1 ,@(and count2 (list count2)))))

@export
(defun offset (offset)
  (make-clause :offset offset))

@export
(defmacro set= (&rest args)
  `(make-clause :set= ,@args))

@export
(defmacro left-join (table &key on using)
  `(make-left-join-clause (detect-and-convert ,(expand-op table))
                          :on ,(expand-op on)
                          :using ',using))
