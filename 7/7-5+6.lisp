;;; From Paul Graham's ANSI Common Lisp
;;; Figure 7.1, Page 127
;;;
;;; 02/05/08 Fixed start index bug in buf-flush [CKR]

(defstruct buf
  vec (start -1) (used -1) (new -1) (end -1))

(defun bref (buf n)
  (svref (buf-vec buf)
         (mod n (length (buf-vec buf)))))

(defun (setf bref) (val buf n)
  (setf (svref (buf-vec buf)
               (mod n (length (buf-vec buf))))
        val))

(defun new-buf (len)
  (make-buf :vec (make-array len)))

(defun buf-insert (x b)
  (setf (bref b (incf (buf-end b))) x))

(defun buf-pop (b)
  (prog1 
    (bref b (incf (buf-start b)))
    (setf (buf-used b) (buf-start b)
          (buf-new  b) (buf-end   b))))

(defun buf-next (b)
  (when (< (buf-used b) (buf-new b))
    (bref b (incf (buf-used b)))))

(defun buf-reset (b)
  (setf (buf-used b) (buf-start b)
        (buf-new  b) (buf-end   b)))

(defun buf-clear (b)
  (setf (buf-start b) -1 (buf-used  b) -1
        (buf-new   b) -1 (buf-end   b) -1))

(defun buf-flush (b str)
  (do ((i (1+ (buf-start b)) (1+ i)))
      ((> i (buf-end b)))
    (princ (bref b i) str)))

;;; From Paul Graham's ANSI Common Lisp
;;; Figure 7.2, Page 129
;;;
;;; Requires fixed version of buf.lisp

(defun file-subst (old new file1 file2)
  (with-open-file (in file1 :direction :input)
     (with-open-file (out file2 :direction :output
                                :if-exists :supersede)
       (stream-subst old new in out))))

(defun match-char-p (old new wildcard)
  (or (eql old new)
      (eql old wildcard)
      (case old
        (:alpha (alpha-char-p new))
        (:digit (digit-char-p new))
        (:alphanumeric (or (alpha-char-p new) (digit-char-p new)))
        (:wild t))))

(defun stream-subst (old new in out &key (wildcard #\+))
  (let* ((pos 0)
         (len (length old))
         (buf (new-buf len))
         (from-buf nil))
    (do ((c (read-char in nil :eof)
            (or (setf from-buf (buf-next buf))
                (read-char in nil :eof))))
        ((eql c :eof))
      (cond ((match-char-p (elt old pos) c wildcard)
             (incf pos)
             (cond ((= pos len)            ; 3
                    (princ new out)
                    (setq pos 0)
                    (buf-clear buf))
                   ((not from-buf)         ; 2
                    (buf-insert c buf))))
            ((zerop pos)                   ; 1
             (princ c out)
             (when from-buf
               (buf-pop buf)
               (buf-reset buf)))
            (t                             ; 4
             (unless from-buf
               (buf-insert c buf))
             (princ (buf-pop buf) out)
             (buf-reset buf)
             (setf pos 0))))
    (buf-flush buf out)))
