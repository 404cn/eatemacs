;;; -*- lexical-binding: t -*-

;; curl -L -O https://github.com/rime/librime/releases/download/1.7.2/rime-1.7.2-osx.zip
;; unzip rime-1.7.2-osx.zip -d ~/.config/emacs/librime
;; rm -rf rime-1.7.2-osx.zip
(eat-package rime
  :straight t
  :commands toggle-input-method
  :init
  (defun +rime-predicate-org-syntax-punc-p ()
    (when (eq major-mode 'org-mode)
      (member rime--current-input-key '(91 93 42 126))))

  (defun +rime-predicate-md-syntax-punc-p ()
    (when (eq major-mode 'markdown-mode)
      (member rime--current-input-key '(91 93 96))))

  (setq rime-disable-predicates '(meow-normal-mode-p
                                  ;; meow-motion-mode-p
                                  meow-keypad-mode-p
                                  meow-beacon-mode-p
                                  +rime-predicate-org-syntax-punc-p
                                  +rime-predicate-md-syntax-punc-p)
        rime-inline-predicates '(rime-predicate-space-after-cc-p
                                 rime-predicate-current-uppercase-letter-p
                                 +rime-predicate-md-syntax-punc-p)
        rime-translate-keybindings '("C-f" "C-b" "C-n" "C-p" "C-g" "C-v" "M-v")
        rime-inline-ascii-holder ?a
        default-input-method "rime"
        rime-cursor "|"
        rime-show-candidate 'minibuffer)
  (when eat/macp
    (setq rime-librime-root (expand-file-name "librime/dist" user-emacs-directory)))
  :config
  (set-face-attribute 'rime-indicator-face nil :height 0.9)
  (set-face-attribute 'rime-indicator-dim-face nil :height 0.9)
  (define-key rime-active-mode-map [tab] 'rime-inline-ascii)
  (define-key rime-mode-map (kbd "M-j") 'rime-force-enable))

(eat-package meow
  :straight t
  :hook
  (after-init-hook . (lambda ()
                       (meow-global-mode 1)))
  :init
  (setq meow-visit-sanitize-completion nil)
  :config
  (setq meow-esc-delay 0.001
        meow-keypad-describe-delay 1.0)

  ;; custom indicator
  (setq meow-replace-state-name-list
        '((normal . "🅝")
          (beacon . "🅑")
          (insert . "🅘")
          (motion . "🅜")
          (keypad . "🅚")))

  ;; specific font so that line won't break
  (advice-add 'meow-cheatsheet :after (lambda ()
                                        (interactive)
                                        (setq buffer-face-mode-face '(:family "Menlo"))
                                        (buffer-face-mode +1)))

  ;; normal mode list
  (dolist (mode '(go-dot-mod-mode
                  diff-mode))
    (add-to-list 'meow-mode-state-list `(,mode . normal)))
  ;; motion mode list
  (dolist (mode '(xeft-mode
                  Info-mode
                  ghelp-page-mode
                  notmuch-hello-mode
                  notmuch-search-mode
                  notmuch-tree-mode))
    (add-to-list 'meow-mode-state-list `(,mode . motion)))

  (meow-setup-indicator)
  ;; setup meow with selected keyboard layout
  (require 'init-meow-dvorak)
  (meow-setup-dvorak))

(provide 'init-dog)
