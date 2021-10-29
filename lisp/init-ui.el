;;; -*- lexical-binding: t -*-

;; Optimization
(setq idle-update-delay 1.0)

(setq-default cursor-in-non-selected-windows nil)
(setq highlight-nonselected-windows nil)

(setq fast-but-imprecise-scrolling t)
(setq redisplay-skip-fontification-on-input t)

;; Suppress GUI features and more
(setq use-file-dialog nil
      use-dialog-box nil
      inhibit-splash-screen t
      inhibit-x-resources t
      inhibit-default-init t
      inhibit-startup-screen t
      inhibit-startup-message t
      inhibit-startup-buffer-menu t)

;; Pixelwise resize
(setq window-resize-pixelwise t
      frame-resize-pixelwise t)

(with-no-warnings
  (when sys/macp
    ;; Render thinner fonts
    (setq ns-use-thin-smoothing t)
    ;; Don't open a file in a new frame
    (setq ns-pop-up-frames nil)))

;; Don't use GTK+ tooltip
(when (boundp 'x-gtk-use-system-tooltips)
  (setq x-gtk-use-system-tooltips nil))

;; Linux specific
(setq x-underline-at-descent-line t)

(eat-package nano-theme
  :init
  (setq nano-theme-light/dark 'light
        nano-theme-comment-italic nil
        nano-theme-keyword-italic nil
        nano-theme-overline-modeline t
        nano-theme-padded-modeline nil
        nano-theme-system-appearance t))

(eat-package doom-themes
  :straight t
  :init
  (setq doom-themes-enable-bold t
        doom-themes-enable-italic t
        doom-themes-padded-modeline t
        doom-spacegrey-brighter-comments t
        doom-spacegrey-brighter-modeline t
        doom-spacegrey-comment-bg t)
  :config
  (doom-themes-visual-bell-config)
  (doom-themes-org-config))

(eat-package spacemacs-theme
  :straight t
  :init
  (setq spacemacs-theme-comment-italic t
        spacemacs-theme-keyword-italic t
        spacemacs-theme-org-agenda-height t
        spacemacs-theme-org-bold t
        spacemacs-theme-org-height t
        spacemacs-theme-org-highlight t
        spacemacs-theme-org-priority-bold t
        spacemacs-theme-org-bold t
        spacemacs-theme-underline-parens t))

(eat-package kaolin-themes
  :straight t
  :init
  (setq kaolin-themes-underline-wave nil
        kaolin-themes-modeline-border nil
        kaolin-themes-modeline-padded 4))

;; Nice window divider
(set-display-table-slot standard-display-table
                        'vertical-border
                        (make-glyph-code ?┃))

(eat-package parrot
  :straight t
  :init
  (setq parrot-num-rotations nil))
(eat-package nyan-mode
  :straight t
  :init
  (setq nyan-animate-nyancat t
        nyan-wavy-trail t
        nyan-bar-length 16)
  :config
  (nyan-start-animation))

;; TODO project path | meow | (major-mode) | git | flyc | row,col
;; TODO show window message or eyebrowse, change all other to right side
;; TODO add paded to :eval
;; TODO use diff face in active modeline and deactive modeline
(defun +format-mode-line ()
  ;; TODO use -*-FZSuXinShiLiuKaiS-R-GB-normal-normal-normal-*-*-*-*-*-p-0-iso10646-1
  ;; to show flymake or flycheck errors count in mode line
  (let* ((lhs '((:eval (meow-indicator))
                (:eval (rime-lighter))
                ;; " Row %l Col %C %%p"
                " Row %4l Col %2C "
                (:eval (nyan-create))
                (:eval (propertize " " 'display '(height 1.1))) ;; make mode line fill rime lighter height
                (:eval (parrot-create))
                ;; use 危
                ;; (:eval (when (bound-and-true-p flymake-mode)
                ;;          flymake-mode-line-format))
                ))
         (rhs '((:eval (propertize (+smart-file-name-cached) 'face 'mode-line-buffer-id))
                " "
                (:eval mode-name)
                (vc-mode vc-mode)))
         (ww (window-width))
         (lhs-str (format-mode-line lhs))
         (rhs-str (format-mode-line rhs))
         (rhs-w (string-width rhs-str)))
    (format "%s%s%s"
            lhs-str
            (propertize " " 'display `((space :align-to (- (+ right right-fringe right-margin) (+ 1 ,rhs-w)))))
            rhs-str)))

(setq-default header-line-format nil)

(eat-package doom-modeline
  :straight t
  :init
  (defvar +use-doom-modeline-p nil)
  (unless (and after-init-time +use-doom-modeline-p)
    (setq-default mode-line-format nil))
  (setq doom-modeline-irc nil
        doom-modeline-mu4e nil
        doom-modeline-gnus nil
        doom-modeline-github nil
        doom-modeline-persp-name nil
        doom-modeline-unicode-fallback t
        doom-modeline-enable-work-count nil)
  (setq doom-modeline-icon (and (display-graphic-p) +use-icon-p))
  (setq doom-modeline-project-detection 'project))

(defun +init-ui (&optional frame)
  (when (and (display-graphic-p) (not +use-doom-modeline-p))
    (nyan-mode)
    (parrot-mode))

  (if +use-doom-modeline-p
      (add-hook 'after-init-hook 'doom-modeline-mode)
    (if +use-header-line
        (setq-default
         mode-line-format nil
         header-line-format '(:eval (+format-mode-line)))
      (setq-default mode-line-format '(:eval (+format-mode-line)))) )

  (when (not (display-graphic-p))
    (load-theme +theme-tui t)
    ;; Use terminal background color
    (set-face-background 'default "undefined"))

  (when (display-graphic-p)
    (load-theme +theme t)
    ;; Auto generated by cnfonts
    ;; <https://github.com/tumashu/cnfonts>
    (set-face-attribute
     'default nil
     :font (font-spec :name "-*-Rec Mono Casual-normal-normal-normal-*-*-*-*-*-m-0-iso10646-1"
                      :weight 'normal
                      :slant 'normal
                      :size 15.0))
    (dolist (charset '(kana han symbol cjk-misc bopomofo))
      (set-fontset-font
       (frame-parameter nil 'font)
       charset
       (font-spec :name "FZSuXinShiLiuKaiS-R-GB"
                  :weight 'normal
                  :slant 'normal
                  :size 18.0)))
    (set-fontset-font t 'unicode +font-unicode nil 'prepend)
    (set-fontset-font t 'symbol (font-spec :family +font-unicode) frame 'prepend)
    (set-face-attribute 'variable-pitch frame :font +font-variable-pitch)
    ;; rescale variable pitch font
    (setf (alist-get +font-variable-pitch face-font-rescale-alist 1.3 nil 'string=) 1.3)

    (set-frame-parameter frame 'internal-border-width 10)
    (setq-default left-margin-width 0 right-margin-width 2)
    (set-window-margins nil 0 0)

    (eat-package ligature
      :straight (ligature :type git :host github :repo "mickeynp/ligature.el")
      :require t
      :config
      (global-ligature-mode)
      ;; https://htmlpreview.github.io/?https://github.com/kiliman/operator-mono-lig/blob/master/images/preview/normal/index.html
      (ligature-set-ligatures 'prog-mode
                              '("&&" "||" "|>" ":=" "==" "===" "==>" "=>"
                                "=<<" "!=" "!==" ">=" ">=>" ">>=" "->" "--"
                                "-->" "<|" "<=" "<==" "<=>" "<=<" "<!--" "<-"
                                "<->" "<--" "</" "+=" "++" "??" "/>" "__" "WWW")))))

(defun +reload-ui-in-daemon (frame)
  "Reload the modeline and font in an daemon frame."
  (with-selected-frame frame
    (+init-ui frame)))

;; Load the modeline and fonts
(if (daemonp)
    (add-hook 'after-make-frame-functions #'+reload-ui-in-daemon)
  (+init-ui))

(provide 'init-ui)
