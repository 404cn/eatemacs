;;; -*- lexical-binding: t -*-

(straight-use-package 'go-mode)
(straight-use-package 'gotest)
(straight-use-package 'go-gen-test)
(straight-use-package 'go-dlv)
(straight-use-package 'go-fill-struct)
(straight-use-package 'go-impl)
(straight-use-package 'go-tag)
(straight-use-package '(flymake-golangci :type git :host gitlab :repo "shackra/flymake-golangci"))

;; go-mode
(add-hook 'before-save-hook 'gofmt-before-save)

(setq gofmt-command "goimports")

(with-eval-after-load "exec-path-from-shell"
  (exec-path-from-shell-copy-envs '("GOPATH" "GO111MODULE" "GOPROXY")))

(with-eval-after-load "go-mode"
  (add-hook 'go-mode-hook 'eglot-ensure)
  (define-key go-mode-map (kbd "C-c t g") #'go-gen-test-dwim)
  (define-key go-mode-map (kbd "C-c t m") #'go-test-current-file)
  (define-key go-mode-map (kbd "C-c t .") #'go-test-current-test)
  (define-key go-mode-map (kbd "C-c t t") #'go-tag-add)
  (define-key go-mode-map (kbd "C-c t T") #'go-tag-remove)
  (define-key go-mode-map (kbd "C-c t x") #'go-run))

;; flymake-golangci
(add-hook 'go-mode-hook 'flymake-golangci-load)

;; go-tag
(setq go-tag-args (list "-transform" "camelcase"))

(provide 'init-go)
