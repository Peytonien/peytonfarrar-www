(in-package :cl-user)
(defpackage peytonwww.web
  (:use :cl
        :caveman2
        :peytonwww.config
        :peytonwww.view
        :peytonwww.db
        :datafly
        :sxql
        :local-time)
  (:export :*web*))
(in-package :peytonwww.web)

;;
;; Application

(defclass <web> (<app>) ())
(defvar *web* (make-instance '<web>))
(clear-routing-rules *web*)

;;
;; Helper funtions

(defun root-path (file-path)
  "Returns the application root path"
  (merge-pathnames file-path *application-root*))

(defun root-directory (directory-path)
  "Returns the files in the directory with respect to the application root"
  (directory (root-path directory-path)))

(defun random-file (files)
  "Given a list of files, returns a random element"
  (nth (random (list-length files)) files))

(defmacro with-group (group &body body)
  "Ensures the user is a member of the group"
  `(if (search ,group (gethash :groups *session*))
       (progn ,@body)
       (throw-code 403)))

(defmacro with-item (item &body body)
  "Ensures the item is a non-nil value"
  `(if ,item
       (progn ,@body)
       (throw-code 404)))

(defmacro aif (test then else)
  "Anaphoric if, provides a reference to the test condition"
  `(let ((it ,test))
     (if ,test
         ,then
         ,else)))

;;
;; User functions

(defstruct user
  id
  username
  password
  groups)

(defun login (username password)
  "Returns the user with the corresponding username and password"
  (with-item (and username password)
    (with-connection (db)
      (retrieve-one
       (select :*
               (from :users)
               (where (:and (:= :username username)
                            (:= :password (:crypt password :password)))))
       :as 'user))))

;;
;; General routing rules

(defroute "/" ()
  (render "index.html"))

(defroute ("/login" :method :GET) (&key |error|)
  (render "login.html"
          (when (string= |error| "t")
            (list :text "Incorrect username or password"))))

(defroute ("/login" :method :POST) (&key |username| |password|)
  (let ((current-user (login |username| |password|)))
    (unless current-user (redirect "?error=t"))
    (when current-user
      (setf (gethash :username *session*) |username|)
      (setf (gethash :groups *session*) (user-groups current-user))
      (redirect "/blog/new"))))

(defroute "/logout" ()
  (clrhash *session*)
  (redirect "/login"))

(defroute "/jazz" ()
  (let ((images (root-directory "static/images/Night/*.jpg"))
        (songs (root-directory "static/music/Jazz/*.ogg")))
    (render "jazz.html"
            (list :image (enough-namestring
                          (random-file images)
                          *static-directory*)
                  :song (enough-namestring
                         (random-file songs)
                         *static-directory*)))))
;;
;; Error pages

(let ((http-error
       '((404 . "Not Found")
         (403 . "Insufficient Permissions"))))
  (defun error-reason (error-code)
    (cdr (assoc error-code http-error))))

(defmethod on-exception ((app <web>) error-code)
  (declare (ignore app))
  (render "error.html"
          (list :error-code error-code :error-message (error-reason error-code))))
