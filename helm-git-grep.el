;;; helm-git-grep.el --- Quick listing and execution of rake tasks.
;; This file is not part of Emacs

;; Copyright (C) 2011 Jose Pablo Barrantes
;; Created: Fri Jun 28 14:27:32 2013
;; Version: 0.1.0

;;; Commentary:
;;; Installation:
;; Put this file where you defined your `load-path` directory or just
;; add the following line to your emacs config file:

;; (load-file "/path/to/helm-git-grep.el")

;; Finally require it:
;; (require 'helm-git-grep)

;; Usage:
;; M-x helm-git-grep

;; There is no need to setup load-path with add-to-list if you copy
;; `helm-git-grep.el` to load-path directories.

;; Requirements:
;; http://www.emacswiki.org/emacs/Helm
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Code:
(require 'helm)

;;; --------------------------------------------------------------------
;;; - Customization
;;;
(defvar *helm-git-grep-buffer-name*
  "*Helm git grep*")

(defvar  helm-git-grep-cmd
  "cd %s && git   \
  --no-pager grep \
  --line-number   \
  --no-color      \
  --extended-regexp %s")

(defvar helm-c-source-git-grep
  '((name . "Helm Git Grep")
    (candidates-process . helm-git-grep-init)
    (requires-pattern . 1)
    (candidate-number-limit . 9999)
    (action . helm-git-grep-action))
  "Find files matching the current input pattern.")

(defun helm-git-grep-find-repo (dir)
  "Recursively search for a .git/ DIR."
  (if (string= "/" dir)
      (message "not in a git repo.")
    (if (file-exists-p (expand-file-name ".git/" dir))
        dir
      (helm-git-grep-find-repo (expand-file-name "../" dir)))))

(defun helm-git-grep-init ()
  "Git grep files."
  (setq mode-line-format
        '(" " mode-line-buffer-identification " "
          (line-number-mode "%l") " "
          (:eval (propertize "(Git grep Running) "
                             'face '((:foreground "red"))))))
  (prog1
      (start-process-shell-command
       "helm-git-grep-process" nil
       (format helm-git-grep-cmd
               (helm-git-grep-find-repo
                default-directory)
               helm-pattern))
    (set-process-sentinel
     (get-process "helm-git-grep-process")
     #'(lambda (process event)
         (when (string= event "finished\n")
           (with-helm-window
             (kill-local-variable 'mode-line-format)
             (helm-update-move-first-line)
             (helm-git-grep-fontify)
             (setq mode-line-format
                   '(" " mode-line-buffer-identification " "
                     (line-number-mode "%l") " "
                     (:eval (propertize
                             (format "[Git Grep Process Finished - (%s results)] "
                                     (let ((nlines (1- (count-lines
                                                        (point-min)
                                                        (point-max)))))
                                       (if (> nlines 0) nlines 0)))
                             'face 'helm-grep-finish))))))))))

(defvar file-full-path)
(defun helm-git-grep-action (candidate)
  (string-match ":\\([0-9]+\\):" candidate)
  (save-match-data
    (setq file-full-path
          (concat
           (helm-git-grep-find-repo default-directory)
           (substring candidate 0 (match-beginning 0))))
    (if (file-exists-p file-full-path)
        (find-file file-full-path)))
  (goto-line (string-to-number (match-string 1 candidate)))
  (if (get-buffer *helm-git-grep-buffer-name*)
      (kill-buffer *helm-git-grep-buffer-name*)))

(defun helm-git-grep-fontify ()
  (goto-char 1)
  (while (re-search-forward (concat
                             "\\(.*\\)\\(:\\)\\([0-9]+\\)\\(:\\)\\(.*\\)\\("
                             helm-pattern
                             "\\)\\(.*\\)") nil t)
    (put-text-property (match-beginning 1) (match-end 1)
                       'face compilation-info-face)
    (put-text-property (match-beginning 3) (match-end 3)
                       'face compilation-line-face)
    (put-text-property (match-beginning 6) (match-end 6)
                       'face compilation-warning-face)
    (forward-line 1)))

;;;###autoload
(defun helm-git-grep ()
  "Return the list of git(1) grep(1) results."
  (interactive)
  (helm-other-buffer
   '(helm-c-source-git-grep) *helm-git-grep-buffer-name*))

(provide 'helm-git-grep)
;;; helm-git-grep.el ends here
