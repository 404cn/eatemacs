;;; -*- lexical-binding: t -*-

;; Edit and rename this file to custom.el

;; Enable copilot, also check `copilot-install-server' and `copilot-login'
;; (add-hook 'prog-mode-hook #'copilot-mode)

;; Set gptel backend
;; (with-eval-after-load 'gptel
;;   (setq gptel-backend (gptel-make-openai "SB OpenAI"
;;                         :host "api.openai-sb.com"
;;                         :key (retrieve-authinfo-key "api.openai-sb.com" "apikey")
;;                         :stream t
;;                         :models '("gpt-4"))))
