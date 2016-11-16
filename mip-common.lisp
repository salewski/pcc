(in-package #:pcc)

(defstruct (dopest (:constructor make-dopest (dopeop opst dopeval)))
  dopeop opst dopeval)

(defvar dope (make-hash-table))
(defvar opst (make-hash-table))

(defvar indope
  (list 
   (make-dopest 'NAME "NAME" '(LTYPE))
   (make-dopest 'REG "REG" '(LTYPE))
   (make-dopest 'OREG "OREG" '(LTYPE))
   (make-dopest 'TEMP "TEMP" '(LTYPE))
   (make-dopest 'ICON "ICON" '(LTYPE))
   (make-dopest 'FCON "FCON" '(LTYPE))
   (make-dopest 'CCODES "CCODES" '(LTYPE))
   (make-dopest 'UMINUS "U-" '(LTYPE))
   (make-dopest 'UMUL "U*" '(LTYPE))
   (make-dopest 'FUNARG "FUNARG" '(LTYPE))
   (make-dopest 'UCALL "UCALL" '(LTYPE CALLFLG))
   (make-dopest 'UFORTCALL "UFCALL" '(UTYPE CALLFLG))
   (make-dopest 'COMPL "~" '(UTYPE))
   (make-dopest 'FORCE "FORCE" '(UTYPE))
   (make-dopest 'XARG "XARG" '(UTYPE))
   (make-dopest 'XASM "XASM" '(BITYPE))
   (make-dopest 'SCONV "SCONV" '(UTYPE))
   (make-dopest 'PCONV "PCONV" '(UTYPE))
   (make-dopest 'PLUS "+" '(BITYPE FLOFLG SIMPFLG COMMFLG))
   (make-dopest 'MINUS "-" '(BITYPE FLOFLG SIMPFLG))
   (make-dopest 'MUL "+" '(BITYPE FLOFLG MULFLG))
   (make-dopest 'AND "&" '(BITYPE SIMPFLG COMMFLG))
   (make-dopest 'CM "," 'BITYPE)
   (make-dopest 'ASSIGN "=" '(BITYPE ASGFLG))
   (make-dopest 'DIV "/" '(BITYPE FLOFLG MULFLG DIVFLG))
   (make-dopest 'MOD "%" '(BITYPE DIVFLG))
   (make-dopest 'LS "<<" '(BITYPE SHFFLG))
   (make-dopest 'RS ">>" '(BITYPE SHFFLG))
   (make-dopest 'OR "|" '(BITYPE COMMFLG SIMPFLG))
   (make-dopest 'ER "^" '(BITYPE COMMFLG SIMPFLG))
   (make-dopest 'CALL "CALL" '(BITYPE CALLFLG))
   (make-dopest 'FORTCALL "FCALL" '(BITYPE CALLFLG))
   (make-dopest 'EQ "==" '(BITYPE LOGFLG))
   (make-dopest 'NE "!=" '(BITYPE LOGFLG))
   (make-dopest 'LE "<=" '(BITYPE LOGFLG))
   (make-dopest 'LT "<" '(BITYPE LOGFLG))
   (make-dopest 'GE ">=" '(BITYPE LOGFLG))
   (make-dopest 'GT ">" '(BITYPE LOGFLG))
   (make-dopest 'UGT "UGT" '(BITYPE LOGFLG))
   (make-dopest 'UGE "UGE" '(BITYPE LOGFLG))
   (make-dopest 'ULT "ULT" '(BITYPE LOGFLG))
   (make-dopest 'ULE "ULE" '(BITYPE LOGFLG))
   (make-dopest 'CBRANCH "CBRANCH" '(BITYPE))
   (make-dopest 'FLD "FLD" '(UTYPE))
   (make-dopest 'PMCONV "PMCONV" '(BITYPE))
   (make-dopest 'PVCONV "PVCONV" '(BITYPE))
   (make-dopest 'RETURN "RETURN" '(BITYPE ASGFLG ASGOPFLG))
   (make-dopest 'GOTO "GOTO" '(UTYPE))
   (make-dopest 'STASG "STASG" '(BITYPE ASGFLG))
   (make-dopest 'STARG "STARG" '(UTYPE))
   (make-dopest 'STCALL "STCALL" '(BITYPE CALLFLG))
   (make-dopest 'USTCALL "USTCALL" '(UTYPE CALLFLG))
   (make-dopest 'ADDROF "U&" '(UTYPE))))

(defvar nerrors)
(defvar ftitle "<stdin>")
(defvar lineno)
(defvar savstringsz)
(defvar newattrsz)
(defvar nodesszcnt)
(defvar warniserr)

(defun WHERE ()
  (format *error-output* "~a, line ~a: " ftitle lineno))

(defun incerr ()
  (when (> (incf nerrors) 30)
    (error "too many errors")))

;; nonfatal error message
;; the routine where is different for pass 1 and pass 2;
;; it tells where the error took place

(defun uerror (s &rest ap)
  (WHERE)
  (apply #'format *error-output* s ap)
  (format *error-output* "~%")
  (incerr))

;; compiler error: die
(defun _cerror (s &rest ap)
  (WHERE)
  (cond 
   ((>= 1 nerrors 30)
    (format *error-output*
            "cannot recover from earlier errors: goodbye!~%"))
   (t
    (format *error-output* "compiler error: ")
    (apply #'format *error-output* s ap)
    (format *error-output* "~%")
    (error 'exit-pcc))))

;; warning
(defun u8error (s &rest ap)
  (WHERE)
  (format *error-output* "warning: ")
  (apply #'format *error-output* s ap)
  (format *error-output* "~%")
  (when warniserr (incerr)))

(defvar wdebug)

;; warning
(defun werror (s &rest ap)
  (unless wdebug
    (WHERE)
    (format *error-output* "warning: ")
    (apply #'format *error-output* s ap)
    (format *error-output* "~%")
    (when warniserr (incerr))))

(defstruct (_warning (:constructor make-warning (flag warn err fmt)))
  flag warn err fmt)

;; conditional warnings
(defvar warnings
  (list
   (make-warning "truncate" 0 0
                 "conversion from '~a' to '~a' may alter its value")
   (make-warning "strict-prototypes" 0 0
                 "function declaration isn't a prototype")
   (make-warning "missing-prototypes" 0 0
                 "no previous prototype for `~a'")
   (make-warning "implicit-int" 0 0
                 "return type defaults to `int'")
   (make-warning "shadow" 0 0
                 "declaration of '~a' shadows a ~a declaration")
   (make-warning "pointer-sign" 0 0
                 "pointer sign mismatch")
   (make-warning "sign-compare" 0 0
                 "comparison between signed and unsigned")
   (make-warning "unknown-pragmas" 0 0
                 "ignoring #pragma ~a ~a")
   (make-warning "unreachable-code" 0 0
                 "statement not reached")
   (make-warning "deprecated-declarations" 1 0
                 "`~a' is deprecated")
   (make-warning "attributes" 1 0
                 "unsupported attribute `~a'")))

;; set the warn/err status of a conditional warning
(defun wset (str warn err)
  (dolist (w warnings)
    (when (string= str (_warning-flag w))
      (setf (_warning-warn w) warn
            (_warning-err w) err)
      (return 0)))
  1)

(defun Wflags (ww)
  (let ((isset 1)
        (iserr 0)
        (str (string-downcase (symbol-name ww))))
    (cond
     ((eq ww 'error)
      ; handle -Werror specially
      (dolist (w warnings)
        (setf (_warning-err w) 1))
      (setf warniserr 1))
     (t
      (when (string= (subseq str 0 3) "no-")
        (setf isset 0 str (subseq str 3)))
      (when (string= (subseq str 0 6) "error=")
        (setf iserr 1 str (subseq str 6)))
      (let ((w (find str warnings #:key #'_warning-flag #:test #'string=)))
        (if w
            (cond 
             ((/= isset 0) 
              (when (/= iserr 0) (setf (_warning-err w) 1))
              (setf (_warning-warn w) 1))
             ((/= iserr 0) (setf (_warning-err w) 0))
             (t (setf (_warning-warn w) 0)))
            (format *error-output* "unrecognised warning option '~a'~%" str)))))))

(defun warner (type &rest ap)
  (unless (and (eq type 'Wtruncate) (> issyshdr 0)) ; Too many false positives
    (let* (_t
           (str (subseq (string-downcase (symbol-name ww)) 1))
           (w (find str warnings #:key #'_warning-flag #:test #'string=)))
      (unless (= (_warning-warn w) 0) ; no warning
       (cond
        ((/= (_warning-err w) 0) (setf _t "error") (incerr))
        (t 
         (setf _t "warning")))
       (format *error-output* "~a:~a: ~a: " ftitle lineno _t)
       (apply #'format *error-output* s ap)
       (format *error-output* "~%")))))

(defun mkdope ()
  (setf nerrors 0 warniserr 0)
  (dolist (q indope)
    (setf (gethash (dopest-dopeop q) dope) (dopest-dopeval q))
    (setf (gethash (dopest-dopeop q) opst) (dopest-opst q))))

  