;; -*- lexical-binding: t; -*-

(eat-package telega
  :straight t
  :commands telega
  :init
  (defun +telega-font-setup ()
    (interactive)
    (setq buffer-face-mode-face `(:family ,eat/font-cn))
    (buffer-face-mode +1))
  :hook
  ;; font setup
  ((telega-root-mode-hook telega-chat-mode-hook) . +telega-font-setup)
  :config
  ;; ignore blocked user
  (add-hook 'telega-msg-ignore-predicates
            (telega-match-gen-predicate "msg-" '(sender blocked)))

  (setq telega-chat-input-prompt "> "
        telega-animation-play-inline nil
        telega-video-play-inline nil
        ;; make sticker larger to read
        telega-sticker-size '(10 . 24)
        ;; change reply symbol
        telega-symbol-reply "↫"
        ;; set date format for old messages
        telega-old-date-format "%Y/%M/%D")

  (custom-set-faces
   '(telega-entity-type-pre ((t :inherit 'fixed-pitch :family nil))))

  ;; enable some completion in telega chatbuf
  (setq telega-emoji-company-backend 'telega-company-emoji)

  (with-eval-after-load 'company
    (defun my-telega-chat-mode ()
      (set (make-local-variable 'company-backends)
           (append (list telega-emoji-company-backend
                         'telega-company-username
                         'telega-company-hashtag)
                   (when (telega-chat-bot-p telega-chatbuf--chat)
                     '(telega-company-botcmd))))
      (company-mode 1))
    (add-hook 'telega-chat-mode-hook 'my-telega-chat-mode))

  ;; syntax highlighting in telega code
  (require 'telega-mnz)
  (global-telega-mnz-mode 1))

(eat-package magit
  :straight t
  :hook
  (git-commit-setup-hook . git-commit-turn-on-flyspell)
  (magit-diff-visit-file . my-recenter-and-pulse-line)
  :commands magit
  :init
  (defun eat/magit-yadm ()
    (interactive)
    (magit-status "/yadm::"))
  :config
  (fullframe magit-status magit-mode-quit-window)
  (setq-default magit-diff-refine-hunk t)
  (global-set-key (kbd "C-x g") 'magit-status)
  (global-set-key (kbd "C-x M-g") 'magit-dispatch))

(when (executable-find "delta")
  (eat-package magit-delta
    :straight t
    :init
    (add-hook 'magit-mode-hook (lambda () (magit-delta-mode +1)))))

(eat-package diff-hl
  :straight t
  :commands diff-hl-mode
  :hook
  ((prog-mode-hook conf-mode-hook) . diff-hl-mode)
  (dired-mode-hook . diff-hl-dired-mode)
  (magit-pre-refresh-hook . diff-hl-magit-pre-refresh)
  (magit-post-refresh-hook . diff-hl-magit-post-refresh)
  :init
  (setq diff-hl-draw-borders nil)
  :config
  ;; Highlight on-the-fly
  (diff-hl-flydiff-mode 1)

  (unless (display-graphic-p)
    ;; Fall back to the display margin since the fringe is unavailable in tty
    (diff-hl-margin-mode 1)
    ;; Avoid restoring `diff-hl-margin-mode'
    (with-eval-after-load 'desktop
      (add-to-list 'desktop-minor-mode-table
                   '(diff-hl-margin-mode nil)))))

(eat-package dirvish :straight t)
(eat-package fd-dired :straight t)

(defface eat/notmuch-tag-emacs
  '((t :foreground "systemPurpleColor"))
  "Default face used for the Emacs tag.

Used in the default value of `notmuch-tag-formats'."
  :group 'notmuch-faces)

(defface eat/notmuch-tag-golang
  '((t :foreground "systemBlueColor"))
  "Default face used for the golang tag.

Used in the default value of `notmuch-tag-formats'."
  :group 'notmuch-faces)

(eat-package notmuch
  :straight t
  :commands notmuch
  :init
  (setq notmuch-search-oldest-first nil
        notmuch-search-result-format '(("date" . "%12s ")
                                       ("count" . "%-11s ")
                                       ("authors" . "%-20s ")
                                       ("subject" . "%-80s ")
                                       ("tags" . "(%s)"))
        notmuch-show-empty-searches t)
  (defun eat/async-notmuch-poll ()
    (interactive)
    (message "Start polling email...")
    (async-start
     `(lambda ()
        ,(async-inject-variables "\\`load-path\\'")
        (require 'notmuch)
        (notmuch-poll))
     (lambda (result)
       (message "eat/async-notmuch-poll: %s" result)
       (notify-send :title "Emacs" :body result :urgency 'critical))))
  :config
  (add-to-list 'notmuch-tag-formats '("emacs" (propertize tag 'face 'eat/notmuch-tag-emacs)))
  (add-to-list 'notmuch-tag-formats '("golang" (propertize tag 'face 'eat/notmuch-tag-golang)))
  (global-set-key [remap notmuch-poll-and-refresh-this-buffer] #'eat/async-notmuch-poll))

(eat-package docker
  :straight t
  :commands docker
  :config
  (fullframe docker-images tablist-quit)
  (fullframe docker-machines tablist-quit)
  (fullframe docker-volumes tablist-quit)
  (fullframe docker-networks tablist-quit)
  (fullframe docker-containers tablist-quit))

(eat-package kubernetes
  :straight t
  :commands
  kubernetes-overview
  :config
  (setq kubernetes-poll-frequency 3600
        kubernetes-redraw-frequency 3600))

(eat-package devdocs :straight t)

(eat-package ibuffer-vc
  :straight t
  :hook (ibuffer-hook . ibuffer-set-up-preferred-filters)
  :init
  (defun ibuffer-set-up-preferred-filters ()
    (ibuffer-vc-set-filter-groups-by-vc-root)
    (unless (eq ibuffer-sorting-mode 'filename/process)
      (ibuffer-do-sort-by-filename/process))))

(eat-package vterm
  :straight t
  :init
  (setq vterm-always-compile-module t))

(eat-package vterm-toggle
  :straight t
  :init
  (global-set-key (kbd "C-`") #'vterm-toggle))

(eat-package org-static-blog
  :straight t
  :init
  (setq org-static-blog-publish-title "404cn's blog")
  (setq org-static-blog-publish-url "https://404cn.github.io/")
  (setq org-static-blog-publish-directory "~/p/blog/")
  (setq org-static-blog-posts-directory "~/p/blog/posts/")
  (setq org-static-blog-drafts-directory "~/p/blog/drafts/")
  (setq org-static-blog-enable-tags t)
  (setq org-static-blog-use-preview t)
  (setq org-static-blog-preview-ellipsis "")
  (setq org-export-with-toc nil)
  (setq org-export-with-section-numbers nil)
  :config
  (setq org-static-blog-page-header (get-string-from-file "~/p/blog/static/header.html"))
  (setq org-static-blog-page-preamble (get-string-from-file "~/p/blog/static/preamble.html"))
  (setq org-static-blog-page-postamble (get-string-from-file "~/p/blog/static/postamble.html")))

;;; init-app.el ends here
(provide 'init-app)
