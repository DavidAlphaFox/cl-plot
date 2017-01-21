;;;; Martin Kersner, m.kersner@gmail.com
;;;; 2016/11/09
;;;;
;;;; Plot data using GNU plot.
;;;
;;; TODO
;;; better way to build commands!!
;;; check with GNU plot documentation
;;; 3D scatterplot

(in-package :lispplot)

(defparameter *space* " ")
(defparameter *empty* "")

;;; FIGURE
(defclass figure ()
  ((shell :accessor get-shell
          :initform "bash")
   (pt    :accessor get-pt
          :initform 7)
   (ps    :accessor get-ps
          :initform 2)
   (nokey :accessor get-nokey
          :initarg :nokey
          :initform nil)
   (palette :accessor get-palette
            :initarg :palette
            :initform nil)
   (circles :accessor set-circles) ;TODO
   (points :accessor set-points) ;TODO
   (commands :accessor get-commands
             :initform (list ""))
   (stream :accessor get-stream)
   (temporary-files :accessor get-temporary-files
                    :initform nil)))

;;; PRIVATE METHODS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun open-file-to-write ()
  (let* ((filename (get-random-filename))
         (stream (open filename
                      :direction :output
                      :if-exists :overwrite
                      :if-does-not-exist :create)))

    (values filename stream)))

(defgeneric save (fig image-name width height)
  (:documentation "Save a plot as an image."))

(defmethod save ((fig figure) image-name width height)
  (multiple-value-bind (filename stream) (open-file-to-write)

    (write-line "cat << EOF | gnuplot -p" stream)

    (write-line
      (concatenate-strings (list "set term png size"
                                 (concatenate-strings (list width height) ",")))
      stream)

    (write-line
      (concatenate-strings (list "set output \"" image-name "\""))
      stream)

    (build-commands (get-commands fig) stream)

    (write-line "EOF" stream)
    (close stream)
    (ext::shell (concatenate-strings (list (get-shell fig) filename)))
    (mapcar #'(lambda (tmp-file) (delete-file tmp-file)) (get-temporary-files fig))
    (delete-file stream)
    )
)

(defun build-commands (commands stream)
  (mapcar #'(lambda (cmd)
              (write-line (concatenate-strings (list cmd)) stream))
          commands))

;;; SHOW
(defgeneric show (fig)
  (:documentation "Display plot."))

(defmethod show ((fig figure))
  (let* ((cmd-filename (get-random-filename))
         (stream (open cmd-filename
                      :direction :output
                      :if-exists :overwrite
                      :if-does-not-exist :create)))
  
    ;; create temporary file with GNU plot commands
    (write-line "cat << EOF | gnuplot -p" stream)

    ;; setup commands
    ;; nokey
    ;; TODO unify with get-palette
    (if (get-nokey fig)
      (write-line (gen-nokey fig) stream))

    ;; palette
    ;; TODO unify with get-nokey
    (if (get-palette fig)
      (write-line (gen-palette-fig fig) stream))

    ;; printing commands
    (mapcar #'(lambda (cmd)
                (write-line (concatenate-strings (list cmd)) stream))
            (get-commands fig))

    (write-line "EOF" stream)
  
    ;; close file
    (close stream)
  
    ;; plot graph
    (ext::shell (concatenate-strings (list (get-shell fig) cmd-filename)))
  
    ;; remove from temporary data files
    (mapcar #'(lambda (tmp-file) (delete-file tmp-file)) (get-temporary-files fig))

    ;; remove temporary command file
    (delete-file stream)
    ))

;;; SCATTER
(defgeneric scatter (fig df &key with cols palette plot-type fill solid-border lt pt ps)
  (:documentation ""))

(defmethod scatter ((fig figure) df &key
                                 (with nil)
                                 (cols nil)
                                 (palette nil)
                                 (plot-type 'plot)
                                 (fill nil)
                                 (solid-border)
                                 (lt nil) (pt nil) (ps nil))
  (let* ((filename (get-random-filename))
         (stream (open filename
                      :direction :output 
                      :if-exists :overwrite
                      :if-does-not-exist :create)))

    (mapcar #'(lambda (row) (write-line (concatenate-strings row) stream)) df)

    (add-command fig
                 (gen-scatter-type plot-type)
                 (quote-string filename)
                 " using "
                 (gen-cols fig df cols)
                 (gen-with fig with)
                 (gen-pt fig pt)
                 (gen-ps fig ps)
                 (gen-palette-scatter fig palette)
                 (gen-fill fig fill)
                 (gen-solid-border fig solid-border)
                 (gen-lt fig lt)
                 )

    (push filename (get-temporary-files fig))

  (close stream)))

;;; ARROW
(defgeneric arrow (fig X-start Y-start X-end Y-end &key nohead)
  (:documentation "Print arrow."))

(defmethod arrow ((fig figure) X-start Y-start X-end Y-end &key (nohead t))
  (add-command fig
               "set arrow from" *space* X-start "," Y-start *space* "to" *space* X-end "," Y-end *space*
               (gen-subcommand fig nohead "nohead")))

;;; XLABEL
(defgeneric xlabel (fig label)
  (:documentation "Print label for X axis."))

(defmethod xlabel ((fig figure) label)
  (figure-label fig 'x label))

;;; YLABEL
(defgeneric ylabel (fig label)
  (:documentation "Print label for Y axis."))

(defmethod ylabel ((fig figure) label)
  (figure-label fig 'y label))

;;; TITLE
(defgeneric title (fig label)
  (:documentation "Print label for Y axis."))

(defmethod title ((fig figure) label)
  (add-command fig
               "set title " (quote-string label)))

;;; XRANGE
(defgeneric xrange (fig range)
  (:documentation "Adjust range of X axis."))

(defmethod xrange ((fig figure) range)
  (figure-range fig 'x range))

;;; YRANGE
(defgeneric yrange (fig range)
  (:documentation "Adjust range of Y axis."))

(defmethod yrange ((fig figure) range)
  (figure-range fig 'y range))

;;; PRIVATE METHODS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; ADD-COMMAND
(defgeneric add-command (fig &rest cmd)
  (:documentation "Add commands to internal variable commands."))

(defmethod add-command ((fig figure) &rest cmd)
  (nconc
    (get-commands fig)
    (list (concatenate-strings cmd ""))))

;;; SCATTER TYPE: PLOT, REPLOT
;;; TODO sufficient?
(defun gen-scatter-type (scatter-type)
  (concatenate-strings (list *space* (to-str scatter-type) *space*)))

;;; GEN-NOKEY for FIGURE
(defgeneric gen-nokey (fig)
  (:documentation "Block legend."))

(defmethod gen-nokey ((fig figure))
  "set nokey")

;;; PALETTE for FIGURE
(defgeneric gen-palette-fig (fig)
  (:documentation "Show palette on plot."))

(defmethod gen-palette-fig ((fig figure))
  "show palette")

;;; FIGURE-RANGE
;;; General method for setting range of axis.
(defgeneric figure-range (fig axis range)
  (:documentation "Adjust range of figure."))

(defmethod figure-range (fig axis range)
  (add-command fig
    "set" *space* (to-str axis) "range [" (concatenate-strings range ":") "]"))

;;; GEN-WITH
;;; TODO keep as DEFGENERIC, DEFMETHOD?
(defgeneric gen-with (fig with-type)
  (:documentation "Set building blocks for scatter plot."))

(defmethod gen-with ((fig figure) with-type)
  (gen-subcommand fig with-type
                  *space* "with" *space* (to-str with-type) *space*))

;;; GEN-COLS used for SCATTER
;;; TODO keep as DEFGENERIC, DEFMETHOD?
(defgeneric gen-cols (fig df cols)
  (:documentation ""))

(defmethod gen-cols ((fig figure) df cols)
  (if cols
    (concatenate-strings cols ":")
    (concatenate-strings (iota (length (first df)) 1) ":")))

;;; FIGURE-LABEL
;;; General method for setting label of axis.
;;; TODO keep as DEFGENERIC, DEFMETHOD?
(defgeneric figure-label (fig axis label)
  (:documentation "Print label of given axis."))

(defmethod figure-label (fig axis label)
  (add-command fig
               "set" *space* (to-str axis) "label" *space* (quote-string label)))

;;; GEN-SUBCOMMAND
;;; TODO keep as DEFGENERIC, DEFMETHOD?
(defgeneric gen-subcommand (fig val &rest subcommand)
  (:documentation "Auxiliary function for generating substring for commands."))

(defmethod gen-subcommand ((fig figure) val &rest subcommand)
  (if val
    (concatenate-strings subcommand)
    *empty*))

;;; GEN-PT used for SCATTER
;;; TODO keep as DEFGENERIC, DEFMETHOD?
(defgeneric gen-pt (fig val)
  (:documentation "Generate part of 'plot' command related to 'pt' attribute."))

;;; Generate " pt [0-9]+ " if given value is not null
(defmethod gen-pt ((fig figure) val)
  (gen-subcommand fig val
    *space* "pt" *space* (to-str val) *space*))

;;; GEN-PS used for SCATTER
;;; TODO keep as DEFGENERIC, DEFMETHOD?
(defgeneric gen-ps (fig val)
  (:documentation "Generate part of 'plot' command related to 'ps' attribute."))

;;; Generate " ps [0-9]+ " if given value is not null
(defmethod gen-ps ((fig figure) val)
  (gen-subcommand fig val
    *space* "ps" *space* (to-str val) *space*))

;;; GEN-LT used for SCATTER
;;; TODO keep as DEFGENERIC, DEFMETHOD?
(defgeneric gen-lt (fig val)
  (:documentation "Generate part of 'plot' command related to 'lt' attribute."))

;;; Generate " lt [0-9]+ " if given value is not null
(defmethod gen-lt ((fig figure) val)
  (gen-subcommand fig val
    *space* "lt" *space* (to-str val) *space*))

;;; PALETTE for SCATTER
;;; TODO keep as DEFGENERIC, DEFMETHOD?
(defgeneric gen-palette-scatter (fig palette)
  (:documentation "Use palette to display values of points in scatter plot."))

(defmethod gen-palette-scatter ((fig figure) palette)
  (gen-subcommand fig palette
    *space* "palette" *space*))

;;; GEN-FILL used for SCATTER
;;; TODO keep as DEFGENERIC, DEFMETHOD?
(defgeneric gen-fill (fig fill)
  (:documentation "Generate string 'fill' for 'plot' command."))

;;; Generate " fill " if given value is not null
(defmethod gen-fill ((fig figure) fill)
  (gen-subcommand fig fill
    *space* "fill" *space*))

;;; GEN-SOLID-BORDER used for SCATTER
;;; TODO keep as DEFGENERIC, DEFMETHOD?
(defgeneric gen-solid-border (fig solid-border)
  (:documentation "Generate string 'solid border' for 'plot' command."))

;;; Generate " solid border " if given value is not null
(defmethod gen-solid-border ((fig figure) solid-border)
  (gen-subcommand fig solid-border
    *space* "solid border" *space*))
