;;  sunrise-x-modeline.el --- Navigable mode line for the Sunrise Commander File
;;  Manager.

;; Copyright (C) 2009 José Alfredo Romero Latouche (j0s3l0)

;; Author: José Alfredo Romero L. <escherdragon@gmail.com>
;; Keywords: Sunrise Commander Emacs File Manager Path Mode Line

;; This program is free software: you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free Software
;; Foundation,  either  version  3 of the License, or (at your option) any later
;; version.
;;
;; This  program  is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
;; FOR  A  PARTICULAR  PURPOSE.  See the GNU General Public License for more de-
;; tails.

;; You  should have received a copy of the GNU General Public License along with
;; this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This  extension  modifies  the  format  of  the  mode lines under the Sunrise
;; Commander panes so they display only the paths to the current directories (or
;; the tail if the whole path is longer can be displayed on the mode line) and a
;; small icon  indicating  the  current  mode  (normal,  virtual,  synchronized,
;; editable) of its respective pane.

;; The regular mode line format remains available: press C-c m to toggle between
;; one format and the other.

;; The  extension  is  provided  as a minor mode, so you can enable / disable it
;; totally by issuing the command (M-x) sr-modeline.

;; This is version 1 $Rev$ of the Sunrise Commander Modeline Extension.

;; It  was  written  on GNU Emacs 23 on Linux, and tested on GNU Emacs 22 and 23
;; for Linux and on EmacsW32 (version 22) for  Windows.


(require 'sunrise-commander)
(require 'easymenu)

(defconst sr-modeline-norm-mark " * ") ;; ☼
(defconst sr-modeline-sync-mark " = ") ;; ⚓
(defconst sr-modeline-edit-mark " ! ") ;; ⚡
(defconst sr-modeline-virt-mark " @ ") ;; ☯

;;; ============================================================================
;;; Core functions:

(defvar sr-modeline-mark-map (make-sparse-keymap))
(define-key sr-modeline-mark-map [mode-line mouse-1] 'sr-modeline-popup-menu)
(define-key sr-modeline-mark-map [mode-line mouse-2] 'sr-modeline-popup-menu)

(defvar sr-modeline-path-map (make-sparse-keymap))
(define-key sr-modeline-path-map [mode-line mouse-1] 'sr-modeline-navigate-path)
(define-key sr-modeline-path-map [mode-line mouse-2] 'sr-modeline-navigate-path)

(defun sr-modeline-setup ()
  "Determines  the mode indicator (icon) to display in the mode line. On success
  sets the mode line format by calling sr-modeline-set."
  (let ((mark nil))
    (cond ((eq major-mode 'sr-mode)
           (cond ((not buffer-read-only)
                  (setq mark sr-modeline-edit-mark))
                 (sr-synchronized
                  (setq mark sr-modeline-sync-mark))
                 (t
                  (setq mark sr-modeline-norm-mark))))
          ((eq major-mode 'sr-virtual-mode)
           (setq mark sr-modeline-virt-mark)))
    (if mark (sr-modeline-set mark))))

(defun sr-modeline-set (mark)
  "Sets  the mode line format using the given mode indicator and the path to the
  current directory of the pane. Truncates the path  if  it’s  longer  than  the
  available width of the pane."
  (let ((path default-directory)
        (path-length (length default-directory))
        (max-length (- (window-width) 8)))
    (if (< max-length path-length)
        (setq path (concat "..." (substring path (- path-length max-length)))))
    (eval
     `(setq mode-line-format
            '("%[" ,(sr-modeline-mark mark) "%]" ,(sr-modeline-path path))))))

(defun sr-modeline-mark (mark)
  "Prepares  the  propertized string used in the mode line format to display the
  mode indicator."
  (let ((mode-name ""))
    (setq mode-name
          (cond ((eq mark sr-modeline-sync-mark) "Synchronized Navigation")
                ((eq mark sr-modeline-edit-mark) "Editable Pane")
                ((eq mark sr-modeline-virt-mark) "Virtual Directory")
                (t "Normal")))
    (propertize mark
                'font 'bold 
                'mouse-face 'mode-line-highlight
                'help-echo (concat "Sunrise Commander: " mode-name " Mode")
                'local-map sr-modeline-mark-map)))

(defun sr-modeline-path (path)
  "Prepares  the  propertized string used in the mode line format to display the
  path to the current directory in the file system."
  (propertize path
              'local-map sr-modeline-path-map
              'mouse-face 'mode-line-highlight
              'help-echo "Click to navigate directory path"
              'sr-selected-window sr-selected-window))

(defun sr-modeline-navigate-path ()
  "Analyzes  all  click  events  detected  on  the  directory  path and modifies
  accordingly the current directory of the corresponding panel."
  (interactive)
  (let* ((event (caddr (cddadr last-input-event)))
         (path (car event)) (pos (cdr event)))
    (unless (eq sr-selected-window (get-text-property 0 'sr-selected-window path))
      (sr-change-window))
    (let* ((tail-length (- (length (substring-no-properties path)) pos))
           (max-length (length default-directory))
           (target-click (- max-length tail-length))
           (target-end (string-match "/\\|$" default-directory target-click)))
      (when (< target-end max-length)
        (sr-advertised-find-file (substring default-directory 0 target-end))))))

;;; ============================================================================
;;; Private interface:

(defvar sr-modeline-advices nil)

(defun sr-modeline-instrument (function &optional in-other)
  "Creates and appends (but does not activate) a new 'after' advice to the given
  function for mode line format maintenance. If the optional parameter  in-other
  is  not  nil, enforces explicit execution of the advice in both sunrise panes,
  not just in the current one."
 (when (fboundp function)
    (ad-add-advice
     function
     (ad-make-advice
      (intern (concat "sr-modeline-advice-" (symbol-name function))) nil t
      `(advice lambda()
               (setq sr-modeline t)
               (sr-modeline-setup)
               ,(if in-other `(sr-in-other (sr-modeline-setup)))))
     'after 'last)
    (setq sr-modeline-advices
          (append sr-modeline-advices (list function)))))
 
(sr-modeline-instrument 'sr-highlight)
(sr-modeline-instrument 'sr-sync t)
(sr-modeline-instrument 'sr-editable-pane)

(defun sr-modeline-engage ()
  "Activates and enforces the navigation mode line format."
  (mapc 'ad-activate sr-modeline-advices) 
  (sr-modeline-setup)
  (sr-in-other (sr-modeline-setup)))

(defun sr-modeline-disengage ()
  "De-activates the navigation mode line format, enforcing the default one."
  (mapc 'ad-deactivate sr-modeline-advices)
  (setq mode-line-format default-mode-line-format)
  (sr-in-other (setq mode-line-format default-mode-line-format)))

(defun sr-modeline-toggle ()
  "Toggles the usage and enforcement of the navigation mode line format."
  (interactive)
  (if (eq mode-line-format default-mode-line-format)
      (sr-modeline-engage)
    (sr-modeline-disengage)))

;;; ============================================================================
;;; User interface:

(defvar sr-modeline-map (make-sparse-keymap))
(define-key sr-modeline-map "\C-cm" 'sr-modeline-toggle)
(easy-menu-define sr-modeline-menu sr-modeline-map "Sunrise Mode Line"
  '("Sunrise"
    ["Toggle navigation mode line" sr-modeline-toggle t]
    ["Turn off navigation mode line" sr-modeline t]
    ["Navigation mode line help" (lambda ()
                                   (interactive)
                                   (describe-function 'sr-modeline))] ))

(define-minor-mode sr-modeline
  "Navigable  mode  line  for  the  Sunrise Commander. This is a minor mode that
  provides only one keybind:
  
  C-c m ................ Toggle between navigation and default mode line formats
  
  To totally disable this extension do: M-x sr-modeline <RET>"

  nil sr-modeline-norm-mark sr-modeline-map
  (unless (memq major-mode '(sr-mode sr-virtual-mode))
    (setq sr-modeline nil)
    (error "Sorry, this mode can be used only within the Sunrise Commander."))
  (sr-modeline-toggle))

(defun sr-modeline-popup-menu ()
  (interactive)
  (popup-menu sr-modeline-menu))

;;; ============================================================================
;;; Bootstrap:

(defun sr-modeline-start-once ()
  "Bootstraps  the  navigation  mode  line on the first execution of the Sunrise
  Commander, after module installation."
  (sr-modeline t)
  (remove-hook 'sr-start-hook 'sr-modeline-start-once)
  (unintern 'sr-modeline-start-once))
(add-hook 'sr-start-hook 'sr-modeline-start-once)

(provide 'sunrise-x-modeline)
