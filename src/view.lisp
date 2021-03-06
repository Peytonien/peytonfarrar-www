(defpackage #:peytonwww.view
  (:use #:cl)
  (:import-from #:peytonwww.config
                #:*template-directory*)
  (:import-from #:caveman2
                #:*response*
                #:response-headers)
  (:import-from #:djula
                #:add-template-directory
                #:compile-template*
                #:render-template*
                #:*djula-execute-package*)
  (:export #:render))
(in-package :peytonwww.view)

(djula:add-template-directory *template-directory*)

(defparameter *template-registry* (make-hash-table :test 'equal))

(defun render (template-path &optional env)
  (let ((template (gethash template-path *template-registry*))
        (template-path (princ-to-string (merge-pathnames template-path
                                                         *template-directory*))))
    (unless template
      (setf template (djula:compile-template* template-path))
      (setf (gethash template-path *template-registry*) template))
    (apply #'djula:render-template*
           template nil
           env)))

;;
;; Execute package definition

(defpackage #:peytonwww.djula
  (:use #:cl)
  (:import-from #:caveman2
                #:url-for))

(setf djula:*djula-execute-package* (find-package :peytonwww.djula))
