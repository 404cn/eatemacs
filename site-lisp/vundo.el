;;; vundo.el --- Visual undo tree      -*- lexical-binding: t; -*-

;; Author: Yuan Fu <casouri@gmail.com>

;;; This file is NOT part of GNU Emacs

;;; Commentary:
;;
;; To use vundo, type M-x vundo RET in the buffer you want to undo.
;; A undo tree buffer should pop up. To move around, type:
;;
;; f    to go forward
;; b    to go backward
;; n    to go to the node below when you at a branching point
;; p    to go to the node above
;;
;; For developer:
;;
;; In the comments, when I say node, modification, mod, buffer state,
;; they all mean one thing: `vundo-m'. The reason is that `vundo-m'
;; does represent multiple things at once: it represents an
;; modification recorded in `buffer-undo-list', it represents the
;; state of the buffer after that modification took place, and it
;; represents the node in the undo tree in the vundo buffer
;; representing that buffer state.

;;; Code:

(require 'pcase)
(require 'cl-lib)
(require 'seq)

(defun vundo--setup-test-buffer ()
  "Setup and pop a testing buffer.
TYPE is the type of buffer you want."
  (interactive)
  (let ((buf (get-buffer "*vundo-test*")))
    (if buf (kill-buffer buf))
    (setq buf (get-buffer-create "*vundo-test*"))
    (pop-to-buffer buf)))

;;; Customization

(defgroup vundo
  '((vundo-node custom-face)
    (vundo-stem custom-face)
    (vundo-highlight custom-face)
    (vundo-translation-alist custom-variable))
  "Visual undo tree."
  :group 'undo)

(defface vundo-node '((t . (:inherit 'default)))
  "Face for nodes in the undo tree.")

(defface vundo-stem '((t . (:inherit 'default)))
  "Face for stems between nodes in the undo tree.")

(defface vundo-highlight '((t . (:inherit 'default)))
  "Face for the highlighted node in the undo tree.")

(defcustom vundo-translation-alist nil
  "An alist mapping text to their translations.
E.g., mapping ○ to o, ● to *. Key and value must be character,
not string."
  :type 'alist)

;;; Undo list to mod list

(cl-defstruct vundo-m
  "A modification in undo history.
This object serves two purpose: it represents a modification in
undo history, and it also represents the buffer state after the
modification."
  (idx
   nil
   :type integer
   :documentation "The index of this modification in history.")
  (children
   nil
   :type proper-list
   :documentation "Children in tree.")
  (parent
   nil
   :type vundo-m
   :documentation "Parent in tree.")
  (prev-eqv
   nil
   :type vundo-m
   :documentation "The previous equivalent state.")
  (next-eqv
   nil
   :type vundo-m
   :documentation "The next equivalent state.")
  (undo-list
   nil
   :type cons
   :documentation "The undo-list at this modification.")
  (point
   nil
   :type integer
   :documentation "Marks the text node in the vundo buffer if drawn."))

(defun vundo--mod-list-from (undo-list &optional n mod-list)
  "Generate and return a modification list from UNDO-LIST.
If N non-nil, only look at the first N entries in UNDO-LIST.
If MOD-LIST non-nil, extend on MOD-LIST."
  (let ((bound (or n (length undo-list)))
        (uidx 0)
        (mod-list (or mod-list (list (make-vundo-m))))
        new-mlist)
    (while (and (consp undo-list) (< uidx bound))
      ;; Skip leading nils.
      (while (and (< uidx bound) (null (nth uidx undo-list)))
        (cl-incf uidx))
      ;; Add modification.
      (if (< uidx bound)
          (push (make-vundo-m :undo-list (nthcdr uidx undo-list))
                new-mlist))
      ;; Skip through the content of this modification.
      (while (nth uidx undo-list)
        (cl-incf uidx)))
    (append mod-list new-mlist)))

(defun vundo--update-mapping (mod-list &optional hash-table n)
  "Update each modification in MOD-LIST.
Add :idx for each modification, map :undo-list back to each
modification in HASH-TABLE. If N non-nil, start from the Nth
modification in MOD-LIST. Return HASH-TABLE."
  (let ((hash-table (or hash-table
                        (make-hash-table
                         :test #'eq :weakness t :size 200))))
    (cl-loop for mod in (nthcdr (or n 0) mod-list)
             for midx = (or n 0) then (1+ midx)
             do (cl-assert (null (vundo-m-idx mod)))
             do (cl-assert (null (gethash (vundo-m-undo-list mod)
                                          hash-table)))
             do (setf (vundo-m-idx mod) midx)
             do (puthash (vundo-m-undo-list mod) mod hash-table))
    hash-table))

;;; Mod list to tree

(defun vundo--eqv-list-of (mod)
  "Return all the modifications equivalent to MOD."
  (while (vundo-m-prev-eqv mod)
    (cl-assert (not (eq mod (vundo-m-prev-eqv mod))))
    (setq mod (vundo-m-prev-eqv mod)))
  ;; At the first mod in the equiv chain.
  (let ((eqv-list (list mod)))
    (while (vundo-m-next-eqv mod)
      (cl-assert (not (eq mod (vundo-m-next-eqv mod))))
      (setq mod (vundo-m-next-eqv mod))
      (push mod eqv-list))
    (reverse eqv-list)))

(defun vundo--eqv-merge (mlist)
  "Connect modifications in MLIST to be in the same equivalence list.
Order is reserved."
  (cl-loop for idx from 0 to (1- (length mlist))
           for this = (nth idx mlist)
           for next = (nth (1+ idx) mlist)
           for prev = nil then (nth (1- idx) mlist)
           do (setf (vundo-m-prev-eqv this) prev)
           do (setf (vundo-m-next-eqv this) next)))

(defun vundo--sort-mod (mlist &optional reverse)
  "Return sorted modifications in MLIST by their idx...
...in ascending order. If REVERSE non-nil, sort in descending
order."
  (seq-sort (if reverse
                (lambda (m1 m2)
                  (> (vundo-m-idx m1) (vundo-m-idx m2)))
              (lambda (m1 m2)
                (< (vundo-m-idx m1) (vundo-m-idx m2))))
            mlist))

(defun vundo--eqv-merge-mod (m1 m2)
  "Put M1 and M2 into the same equivalence list."
  (let ((l1 (vundo--eqv-list-of m1))
        (l2 (vundo--eqv-list-of m2)))
    (vundo--eqv-merge (vundo--sort-mod (cl-union l1 l2)))))

(defun vundo--build-tree (mod-list mod-hash &optional from)
  "Connect equivalent modifications and build the tree in MOD-LIST.
MOD-HASH maps undo-lists to modifications.
If FROM non-nil, build from FORM-th modification in MOD-LIST."
  (cl-loop
   for m from (or from 0) to (1- (length mod-list))
   for mod = (nth m mod-list)
   ;; If MOD is an undo, the buffer state it represents is equivalent
   ;; to a previous one.
   do (if-let ((prev-undo (undo--last-change-was-undo-p
                           (vundo-m-undo-list mod))))
          (if (eq prev-undo t)
              ;; FIXME: t means this undo is region-undo, currently
              ;; for the convenience of testing we regard t as undo to
              ;; the beginning of history.
              (vundo--eqv-merge-mod (nth 0 mod-list) mod)
            (if-let ((prev-m (gethash prev-undo mod-hash)))
                (vundo--eqv-merge-mod prev-m mod)
              (error "PREV-M shouldn't be nil")))
        ;; If MOD isn't an undo, it represents a new buffer state, we
        ;; connect M-1 with M, where M-1 is the parent and M is the
        ;; child.
        (unless (eq m 0)
          (let* ((m-1 (nth (1- m) mod-list))
                 ;; TODO: may need to optimize.
                 (min-eqv-mod (car (vundo--eqv-list-of m-1))))
            (setf (vundo-m-parent mod) min-eqv-mod)
            (let ((children (vundo-m-children min-eqv-mod)))
              ;; If everything goes right, we should never encounter
              ;; this.
              (cl-assert (not (memq mod children)))
              (setf (vundo-m-children min-eqv-mod)
                    (vundo--sort-mod (cons mod children) 'reverse))))))))

;;; Draw tree

(defun vundo--replace-at-col (from to col &optional until)
  "Replace FROM at COL with TO in each line of current buffer.
If a line is not COL columns long, skip that line."
  (save-excursion
    (let ((run t))
      (goto-char (point-min))
      (while run
        (move-to-column col)
        (if (and (eq (current-column) col)
                 (looking-at (regexp-quote from)))
            (replace-match to))
        ;; If ‘forward-line’ returns 0, we haven’t hit the end of
        ;; buffer.
        (setq run (and (eq (forward-line) 0)
                       (not (eq (point) (point-max)))
                       (< (point) (or until (point-max)))))))))

(defun vundo--put-node-at-point (node)
  "Store the corresponding NODE as text property at point."
  (put-text-property (1- (point)) (point)
                     'vundo-node
                     node))

(defun vundo--get-node-at-point ()
  "Retrieve the corresponding NODE as text property at point."
  (plist-get (text-properties-at (1- (point)))
             'vundo-node))

(defun vundo--next-line-at-column (col)
  "Move point to next line column COL."
  (unless (and (eq 0 (forward-line))
               (not (eq (point) (point-max))))
    (goto-char (point-max))
    (insert "\n"))
  (move-to-column col)
  (unless (eq (current-column) col)
    (let ((indent-tabs-mode nil))
      (indent-to-column col))))

(defun vundo--translate (text)
  "Translate each character in TEXT and return it.
If the character has a mapping in `vundo-translation-alist',
translate to the value."
  (seq-mapcat (lambda (c)
                (char-to-string
                 (alist-get c vundo-translation-alist c)))
              text 'string))

(defun vundo--put-face (beg end face)
  "Add FACE to the text between (+ (point) BEG) and (+ (point) END)."
  (put-text-property (+ (point) beg) (+ (point) end) 'face face))

(defun vundo--draw-tree (mod-list)
  "Draw the tree in MOD-LIST in current buffer."
  (let* ((root (nth 0 mod-list))
         (node-queue (list root))
         (inhibit-read-only t))
    (erase-buffer)
    (while node-queue
      (let* ((node (pop node-queue))
             (children (vundo-m-children node))
             (parent (vundo-m-parent node))
             ;; Is NODE the last child of PARENT?
             (node-last-child-p
              (if parent
                  (eq node (car (last (vundo-m-children parent)))))))
        ;; Go to parent.
        (if parent (goto-char (vundo-m-point parent)))
        (let ((col (max 0 (1- (current-column)))))
          (if (null parent)
              (progn (insert (vundo--translate "○"))
                     (vundo--put-face -1 0 'vundo-node))
            (let ((planned-point (point)))
              ;; If a node is blocking, try next line.
              ;; Example: P--*  Here we want to add
              ;;             |  a child to P but is
              ;;             *  blocked.
              (while (not (looking-at (rx (or "    " eol))))
                (vundo--next-line-at-column col)
                (if (looking-at "$")
                    (insert (vundo--translate "│"))
                  (delete-char 1)
                  (insert (vundo--translate "│")))
                (vundo--put-face -1 0 'vundo-stem))
              ;; Make room for inserting the new node.
              (unless (looking-at "$")
                (delete-char 3))
              ;; Insert the new node.
              (if (eq (point) planned-point)
                  (insert (vundo--translate "──○"))
                ;; Delete the previously inserted |.
                (delete-char -1)
                (if node-last-child-p
                    (insert (vundo--translate "└──○"))
                  (insert (vundo--translate "├──○"))))
              (vundo--put-face -4 -1 'vundo-stem)
              (vundo--put-face -1 0 'vundo-node))))
        ;; Store point so we can later come back to this node.
        (setf (vundo-m-point node) (point))
        ;; Associate the text node in buffer with the node object.
        (vundo--put-node-at-point node)
        ;; Depth-first search.
        (setq node-queue (append children node-queue))))))

;;; Vundo buffer and invocation

(defun vundo--buffer ()
  "Return the vundo buffer."
  (get-buffer-create " *vundo tree*"))

(defun vundo--kill-buffer-if-point-left (window)
  "Kill the vundo buffer if point left WINDOW.
WINDOW is the window that was/is displaying the vundo buffer."
  (if (and (eq (window-buffer window) (vundo--buffer))
           (not (eq window (selected-window))))
      (with-selected-window window
        (kill-buffer-and-window))))

(defvar vundo--mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "f") #'vundo-forward)
    (define-key map (kbd "<right>") #'vundo-forward)
    (define-key map (kbd "b") #'vundo-backward)
    (define-key map (kbd "<left>") #'vundo-backward)
    (define-key map (kbd "n") #'vundo-next)
    (define-key map (kbd "<down>") #'vundo-next)
    (define-key map (kbd "p") #'vundo-previous)
    (define-key map (kbd "<up>") #'vundo-previous)
    (define-key map (kbd "q") #'kill-buffer-and-window)
    (define-key map (kbd "C-g") #'kill-buffer-and-window)
    (define-key map (kbd "i") #'vundo--inspect)
    (define-key map (kbd "d") #'vundo--debug)
    map)
  "Keymap for ‘vundo--mode’.")

(define-derived-mode vundo--mode special-mode
  "Vundo" "Mode for displaying the undo tree."
  (setq mode-line-format nil
        truncate-lines t
        cursor-type nil)
  (jit-lock-mode -1))

(defvar-local vundo--prev-mod-list nil
  "Modification list generated by ‘vundo--mod-list-from’.")
(defvar-local vundo--prev-mod-hash nil
  "Modification hash table generated by ‘vundo--update-mapping’.")
(defvar-local vundo--prev-undo-list nil
  "Original buffer's `buffer-undo-list'.")
(defvar-local vundo--orig-buffer nil
  "Vundo buffer displays the undo tree for this buffer.")
(defvar-local vundo--message nil
  "If non-nil, print information when moving between nodes.")

(defun vundo--mod-list-trim (mod-list n)
  "Remove MODS from MOD-LIST.
Keep the first N modifications."
  (dolist (mod (nthcdr (1+ n) mod-list))
    (let ((parent (vundo-m-parent mod))
          (eqv-list (vundo--eqv-list-of mod)))
      (when parent
        (setf (vundo-m-children parent)
              (remove mod (vundo-m-children parent))))
      (when eqv-list
        (vundo--eqv-merge (remove mod eqv-list)))))
  (seq-subseq mod-list 0 (1+ n)))

(defun vundo--refresh-buffer
    (orig-buffer vundo-buffer &optional incremental)
  "Refresh VUNDO-BUFFER with the undo history of ORIG-BUFFER.
If INCREMENTAL non-nil, reuse some date."
  ;; If ‘buffer-undo-list’ is nil, then we do nothing.
  (with-current-buffer vundo-buffer
    ;; 1. Setting these to nil makes `vundo--mod-list-from',
    ;; `vundo--update-mapping' and `vundo--build-tree' starts from
    ;; scratch.
    (unless incremental
      (setq vundo--prev-undo-list nil
            vundo--prev-mod-list nil
            vundo--prev-mod-hash nil))
    (let ((undo-list (buffer-local-value
                      'buffer-undo-list orig-buffer))
          mod-list
          mod-hash
          (latest-state (and vundo--prev-mod-list
                             (vundo--latest-buffer-state
                              vundo--prev-mod-list)))
          (inhibit-read-only t))
      ;; 1.5 De-highlight the current node before
      ;; `vundo--prev-mod-list' changes.
      (when vundo--prev-mod-list
        (vundo--toggle-highlight
         -1 (vundo--current-node vundo--prev-mod-list)))
      ;; 2. Here we consider two cases, adding more nodes (or starting
      ;; from scratch) or removing nodes. In bot case, we update and
      ;; set MOD-LIST and MOD-HASH.
      (if (> (length undo-list) (length vundo--prev-undo-list))
          ;; a) Adding.
          (let ((diff (- (length undo-list)
                         (length vundo--prev-undo-list))))
            (cl-assert (eq vundo--prev-undo-list (nthcdr diff undo-list)))
            (setq mod-list (vundo--mod-list-from
                            undo-list diff vundo--prev-mod-list)
                  mod-hash (vundo--update-mapping
                            mod-list vundo--prev-mod-hash
                            (length vundo--prev-mod-list)))
            ;; Build tree.
            (vundo--build-tree mod-list mod-hash
                               (length vundo--prev-mod-list)))
        ;; b) Removing.
        (let ((ul undo-list))
          ;; Skip leading nils.
          (while (null (car ul))
            (setq ul (cdr ul)))
          (if-let* ((new-tail (gethash ul vundo--prev-mod-hash))
                    (idx (vundo-m-idx new-tail)))
              (setq mod-list (vundo--mod-list-trim
                              vundo--prev-mod-list idx)
                    mod-hash vundo--prev-mod-hash)
            (error "Couldn't find modification"))))
      ;; 3. Render buffer. We don't need to redraw the tree if there
      ;; is no change to the nodes.
      (unless (eq (vundo--latest-buffer-state mod-list)
                  latest-state)
        (vundo--draw-tree mod-list))
      ;; Highlight current node.
      (vundo--toggle-highlight 1 (vundo--current-node mod-list))
      ;; Update cache.
      (setq vundo--prev-mod-list mod-list
            vundo--prev-mod-hash mod-hash
            vundo--prev-undo-list undo-list
            vundo--orig-buffer orig-buffer))))

(defun vundo--current-node (mod-list)
  "Return the currently highlighted node in MOD-LIST."
  (car (vundo--eqv-list-of (car (last mod-list)))))

(defun vundo--toggle-highlight (arg node)
  "Toggle highlight of NODE.
Highlight if ARG >= 0, de-highlight if ARG < 0."
  (goto-char (vundo-m-point node))
  (if (>= arg 0)
      (add-text-properties (1- (point)) (point)
                           (list 'display (vundo--translate "●")
                                 'face 'vundo-highlight))
    (add-text-properties (1- (point)) (point)
                         (list 'display nil 'face 'vundo-node))))

;;;###autoload
(defun vundo ()
  "Display visual undo for current buffer."
  (interactive)
  (when (not (consp buffer-undo-list))
    (user-error "There is no undo history"))
  (let ((vundo-buf (vundo-1 (current-buffer))))
    (select-window
     (display-buffer-in-side-window
      vundo-buf
      '((side . bottom)
        (window-height . 3))))
    (set-window-dedicated-p nil 'weak)
    (let ((window-min-height 3))
      (fit-window-to-buffer nil (window-height)))
    (goto-char
     (vundo-m-point
      (vundo--current-node vundo--prev-mod-list)))))

(defun vundo-1 (buffer)
  "Return a vundo buffer for BUFFER.
BUFFER must have a valid `buffer-undo-list'."
  (with-current-buffer buffer
    (let* ((vundo-buf (vundo--buffer))
           (orig-buf (current-buffer)))
      (with-current-buffer vundo-buf
        ;; Enable major mode before refreshing the buffer.
        ;; Because major modes kill local variables.
        (unless (derived-mode-p 'vundo--mode)
          (vundo--mode))
        (vundo--refresh-buffer orig-buf vundo-buf)
        vundo-buf))))

;;; Traverse undo tree

(defun vundo--calculate-shortest-route (from to)
  "Calculate the shortest route from FROM to TO node.
Here they represent the source and dest buffer state. Both SETs
are an equivalence set of states. Return (SOURCE STOP1 STOP2 ...
DEST), meaning you should undo the modifications from DEST to
SOURCE. Each STOP is an intermediate stop."
  (let (route-list)
    ;; Find all valid routes.
    (dolist (source (vundo--eqv-list-of from))
      (dolist (dest (vundo--eqv-list-of to))
        ;; We only allow route in this direction.
        (if (> (vundo-m-idx source) (vundo-m-idx dest))
            (push (cons (vundo-m-idx source)
                        (vundo-m-idx dest))
                  route-list))))
    ;; Find the shortest route.
    (setq route-list
          (seq-sort
           (lambda (r1 r2)
             ;; I.e., distance between SOURCE and DEST in R1 compare
             ;; against distance in R2.
             (< (- (car r1) (cdr r1)) (- (car r2) (cdr r2))))
           route-list))
    (let* ((route (car route-list))
           (source (car route))
           (dest (cdr route)))
      (number-sequence source dest -1))))

(defun vundo--list-subtract (l1 l2)
  "Return L1 - L2.

E.g.,

\(vundo--list-subtract '(1 2 3 4) '(3 4))
=> (1 2)"
  (let ((len1 (length l1))
        (len2 (length l2)))
    (cl-assert (> len1 len2))
    (seq-subseq l1 0 (- len1 len2))))

(defun vundo--sans-nil (undo-list)
  "Return UNDO-LIST sans leading nils.
If UNDO-LIST is nil, return nil."
  (while (and (consp undo-list) (null (car undo-list)))
    (setq undo-list (cdr undo-list)))
  undo-list)

(defun vundo--latest-buffer-state (mod-list)
  "Return the node representing the latest buffer state.
Basically, return the latest non-undo modification in MOD-LIST."
  (let ((max-node (car mod-list)))
    (cl-loop for mod in (cdr mod-list)
             do (if (and (null (vundo-m-prev-eqv mod))
                         (> (vundo-m-idx mod)
                            (vundo-m-idx max-node)))
                    (setq max-node mod)))
    max-node))

(defun vundo--move-to-node (current dest orig-buffer mod-list)
  "Move from CURRENT node to DEST node by undoing in ORIG-BUFFER.
ORIG-BUFFER must be at CURRENT state. MOD-LIST is the list you
get from ‘vundo--mod-list-from’. You should refresh vundo buffer
after calling this function."
  ;; 1. Find the route we want to take.
  (if-let* ((route (vundo--calculate-shortest-route current dest)))
      (let* ((source-idx (car route))
             (dest-idx (car (last route)))
             ;; The complete undo-list that stops at SOURCE.
             (undo-list-at-source
              (vundo-m-undo-list (nth source-idx mod-list)))
             ;; The complete undo-list that stops at DEST.
             (undo-list-at-dest
              (vundo-m-undo-list (nth dest-idx mod-list)))
             ;; We will undo these modifications.
             (planned-undo (vundo--list-subtract
                            undo-list-at-source undo-list-at-dest))
             trimmed)
        (with-current-buffer orig-buffer
          ;; 2. Undo. This will undo modifications in PLANNED-UNDO and
          ;; add new entries to ‘buffer-undo-list’.
          (let ((undo-in-progress t))
            (cl-loop
             for step = (- source-idx dest-idx)
             then (1- step)
             while (> step 0)
             for stop = (1- source-idx) then (1- stop)
             do
             (progn
               ;; Stop at each intermediate stop along the route to
               ;; create trim points for future undo.
               (setq planned-undo (primitive-undo 1 planned-undo))
               (cl-assert (not (and (consp buffer-undo-list)
                                    (null (car buffer-undo-list)))))
               (let ((undo-list-at-stop
                      (vundo-m-undo-list (nth stop mod-list))))
                 ;; FIXME: currently we regard t as pointing to root.
                 (puthash buffer-undo-list (or undo-list-at-stop t)
                          undo-equiv-table))
               (push nil buffer-undo-list))))
          ;; 3. Now we may be able to trim the undo-list.
          (let ((latest-buffer-state-idx
                 ;; Among all the MODs that represents a unique buffer
                 ;; state, we find the latest one. Because any node
                 ;; beyond that one is dispensable.
                 (vundo-m-idx
                  (vundo--latest-buffer-state mod-list))))
            (cl-assert (null (undo--last-change-was-undo-p
                              (vundo-m-undo-list
                               (nth latest-buffer-state-idx
                                    mod-list)))))
            ;; Find a trim point between latest buffer state and
            ;; current node.
            (when-let ((possible-trim-point
                        (cl-loop for node in (vundo--eqv-list-of dest)
                                 if (>= (vundo-m-idx node)
                                        latest-buffer-state-idx)
                                 return node
                                 finally return nil)))
              (setq buffer-undo-list
                    (vundo-m-undo-list possible-trim-point)
                    trimmed (vundo-m-idx possible-trim-point))))
          ;; 4. Some misc work.
          (when vundo--message
            (message "%s -> %s Trim to: %s Steps: %s Undo-list len: %s"
                     (mapcar #'vundo-m-idx (vundo--eqv-list-of
                                            (nth source-idx mod-list)))
                     (mapcar #'vundo-m-idx (vundo--eqv-list-of
                                            (nth dest-idx mod-list)))
                     trimmed
                     (length planned-undo)
                     (length buffer-undo-list)))
          (when-let ((win (get-buffer-window)))
            (set-window-point win (point)))))
    (error "No possible route")))

(defun vundo-forward (arg)
  "Move forward ARG nodes in the undo tree.
If ARG < 0, move backward"
  (interactive "p")
  (when (not (buffer-live-p vundo--orig-buffer))
    (user-error "Original buffer is gone"))
  ;; 1.a If ORIG-BUFFER changed since we last synced the vundo buffer
  ;; (e.g., user left vundo buffer and did some edit in ORIG-BUFFER
  ;; then comes back), refresh catch up.
  (if (not (eq (vundo--sans-nil
                (buffer-local-value
                 'buffer-undo-list vundo--orig-buffer))
               (vundo--sans-nil vundo--prev-undo-list)))
      (progn
        (vundo--refresh-buffer vundo--orig-buffer (current-buffer))
        (message "Refresh"))
    ;; 1.b If nothing changed, we are in a good state, move to node.
    (let ((step (abs arg)))
      (let ((node (vundo--current-node vundo--prev-mod-list))
            dest)
        ;; 2. Move to the dest node.
        (while (and node (> step 0))
          (setq dest (if (> arg 0)
                         (car (vundo-m-children node))
                       (vundo-m-parent node)))
          (when dest
            (vundo--move-to-node
             node dest vundo--orig-buffer vundo--prev-mod-list))
          (setq node dest)
          (cl-decf step))
        ;; Refresh display.
        (vundo--refresh-buffer
         vundo--orig-buffer (current-buffer) 'incremental)))))

(defun vundo-backward (arg)
  "Move back ARG nodes in the undo tree.
If ARG < 0, move forward."
  (interactive "p")
  (vundo-forward (- arg)))

(defun vundo-next (arg)
  "Move to node below the current one. Move ARG steps."
  (interactive "p")
  (when (not (buffer-live-p vundo--orig-buffer))
    (user-error "Original buffer is gone"))
  ;; 1.a If ORIG-BUFFER changed since we last synced the vundo buffer
  ;; (e.g., user left vundo buffer and did some edit in ORIG-BUFFER
  ;; then comes back), refresh catch up.
  (if (not (eq (vundo--sans-nil
                (buffer-local-value
                 'buffer-undo-list vundo--orig-buffer))
               (vundo--sans-nil vundo--prev-undo-list)))
      (progn
        (vundo--refresh-buffer vundo--orig-buffer (current-buffer))
        (message "Refresh"))
    ;; 1.b If nothing changed, we are in a good state, move to node.
    (let* ((source (vundo--current-node vundo--prev-mod-list))
           (parent (vundo-m-parent source)))
      ;; Move to next/previous sibling.
      (when parent
        (let* ((siblings (vundo-m-children parent))
               (idx (seq-position siblings source))
               (new-idx (+ idx arg))
               ;; TODO: Move as far as possible instead of not
               ;; moving when ARG is too large.
               (dest (nth new-idx siblings)))
          (when (and dest (not (eq source dest)))
            (vundo--move-to-node
             source dest vundo--orig-buffer vundo--prev-mod-list)
            (vundo--refresh-buffer
             vundo--orig-buffer (current-buffer)
             'incremental)))))))

(defun vundo-previous (arg)
  "Move to node above the current one. Move ARG steps."
  (interactive "p")
  (vundo-next (- arg)))

;;; Debug

(defun vundo--inspect ()
  "Print some useful info at point."
  (interactive)
  (let ((node (vundo--get-node-at-point)))
    (message "Parent: %s States: %s Children: %s"
             (and (vundo-m-parent node)
                  (vundo-m-idx (vundo-m-parent node)))
             (mapcar #'vundo-m-idx (vundo--eqv-list-of node))
             (and (vundo-m-children node)
                  (mapcar #'vundo-m-idx (vundo-m-children node))))))

(defun vundo--debug ()
  "Make cursor visible."
  (interactive)
  (setq cursor-type t
        vundo--message t))


(provide 'vundo)

;;; vundo.el ends here
