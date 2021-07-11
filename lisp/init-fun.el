;;; -*- lexical-binding: t -*-

(eat-package twidget
  :straight (twidget :type git :host github :repo "Kinneyzhang/twidget")
  :init
  ;; FIXME :straight should install multi packages
  (straight-use-package 'ov))

(eat-package svg-lib
  :straight (svg-lib :type git :host github :repo "rougier/svg-lib"))

(eat-package netease-cloud-music
  :straight (netease-cloud-music
             :type git
             :host github
             :repo "SpringHan/netease-cloud-music.el"))

(provide 'init-fun)
