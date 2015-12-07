(in-package :peytonwww.web)

;;
;; Blog post functions

(defstruct post
  id
  subject
  date
  content
  tags)

(defmacro retrieve-post (&body body)
  `(with-connection (db)
     (retrieve-one
      (select :*
        (from :posts)
        ,@body)
      :as 'post)))

(defun latest-post ()
  (retrieve-post
   (order-by (:desc :id))))

(defun post-by-id (id)
  (retrieve-post
   (where (:= :id id))))

(defun get-posts (post-limit &key (post-offset 0) (tag "%"))
  (if (< post-offset 0)
      nil
      (with-connection (db)
        (retrieve-all
         (select :*
                 (from :posts)
                 (offset post-offset)
                 (order-by (:desc :id))
                 (where (:like :tags (concatenate 'string "%" tag "%")))
                 (limit post-limit))))))

(defun render-post (post)
  (render (absolute-path "post.html")
          (list :subject (post-subject post)
                :date (post-date post)
                :content (post-content post)
                :tags (split-sequence:split-sequence #\Space (post-tags post)))))

(defun submit-post (&key subject date content tags)
  (with-connection (db)
    (execute
     (insert-into :posts
                  (set= :subject subject
                        :date date
                        :content content
                        :tags tags)))))

(defun alter-post (id &key subject content tags)
  (with-connection (db)
    (execute
     (update :posts
             (set= :subject subject
                   :content content
                   :tags tags)
             (where (:= :id id))))))

(defun post-count (&optional tag)
  (with-connection (db)
    (cadr
     (retrieve-one
      (select ((:count :*))
              (from :posts)
              (where (:like :tags (concatenate 'string "%" tag "%"))))))))

;;
;; User functions

(defstruct user
  id
  username
  password
  groups)

(defun get-user (username password)
  (with-connection (db)
    (retrieve-one
     (select :*
       (from :users)
       (where (:and (:= :username username)
                    (:= :password (:crypt password :password)))))
     :as 'user)))

;;
;; Routing Rules

(defroute ("/login" :method :GET) (&key |error|)
  (render (absolute-path "login.html")
          (if (string= |error| "t")
              (list :text "  Incorrect username or password"))))

(defroute ("/login" :method :POST) (&key |username| |password|)
  (let ((current-user (get-user |username| |password|)))
    (when (null current-user)
      (redirect "?error=t"))  
    (unless (null current-user)
      (setf (gethash :username *session*) |username|)
      (setf (gethash :groups *session*) (user-groups current-user))
      (redirect "/blog/new"))))

(defroute "/logout" ()
  (clrhash *session*)
  (redirect "/login"))

(defroute ("/blog/post/([\\d]+)" :regexp t) (&key captures)
  (let* ((id (parse-integer (first captures)))
         (post (post-by-id id)))
    (with-item post
      (render-post post))))

(defroute ("/blog/([1-9]+)" :regexp :t) (&key captures)
  (let* ((page (parse-integer (first captures)))
         (limit 20)
         (posts (get-posts limit :post-offset (* limit (1- page)))))
    (with-item posts
      (render (absolute-path "blog_index.html")
              (list :posts posts
                    :previous (if (> page 1) (1- page))
                    :next (if (<= (* limit page) (post-count)) (1+ page)))))))

(defroute ("/blog/tag/([\\w]+)/([\\d]+)" :regexp :t) (&key captures)
  (let* ((tag (first captures))
         (page (parse-integer (second captures)))
         (limit 20)
         (posts (get-posts limit :post-offset (* limit (1- page)) :tag tag)))
    (with-item posts
      (render (absolute-path "blog_index.html")
              (list :posts posts
                    :previous (if (> page 1) (1- page))
                    :next (if (<= (* limit page) (post-count tag)) (1+ page)))))))

(defroute ("/blog/new" :method :GET) (&key |error|)
  (with-group "dev"
    (render (absolute-path "new_post.html")
            (list :title "New Post"))))

(defroute ("/blog/new" :method :POST) (&key |subject| |content| |tags|)
  (with-group "dev"
    (submit-post 
     :subject |subject|
     :date (get-universal-time)
     :content |content|
     :tags |tags|)
    (redirect "/")))

(defroute ("/blog/edit/([\\d]+)" :regexp :t) (&key captures)
  (let* ((id-string (first captures))
         (id (parse-integer id-string))
         (post (post-by-id id)))
    (with-item post
      (with-group "dev"
        (render (absolute-path "new_post.html")
                (list :title "Edit Post"
                      :page (concatenate 'string "/blog/edit/" id-string)
                      :subject (post-subject post)
                      :content (post-content post)
                      :tags (post-tags post)))))))

(defroute ("/blog/edit/([\\d]+)" :regexp :t :method :POST)
    (&key captures |subject| |content| |tags|)
  (let ((id (parse-integer (first captures))))
    (with-group "dev"
      (alter-post id
                  :subject |subject|
                  :content |content|
                  :tags |tags|)
      (redirect "/"))))
