;;; -*- lexical-binding: t -*-

(leaf tab-bar
  :doc "save window layout, gui not work on macos"
  :tag "builtin"
  :when (eq system-type 'gnu/linux)
  :commands
  (tab-bar-mode)
  :bind (("C-c M-t t" . tab-bar-mode)
         ("C-c M-t r" . tab-bar-rename-tab)
         ("C-c M-t n" . tab-bar-new-tab)
         ("C-c M-t d" . tab-bar-close-tab))
  :custom
  (tab-bar-new-tab-choice . "*scratch*")
  (tab-bar-close-button-show . nil)
  (tab-bar-new-button-show . nil))

(leaf ace-window
  :commands
  (ace-swap-window ace-window)
  :custom-face
  (aw-leading-char-face . '((t (:inherit font-lock-keyword-face :bold t :height 3.0))))
  (aw-minibuffer-leading-char-face . '((t (:inherit font-lock-keyword-face :bold t :height 2.0))))
  (aw-mode-line-face . '((t (:inherit mode-line-emphasis :bold t))))
  :custom
  (aw-keys . '(?a ?o ?e ?u ?i))
  (aw-scope . 'frame))

(provide 'init-window)
