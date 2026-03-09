;;; org-modern-right-justify.el --- Enhance visuals for org-modern and org-habit  -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Your Name <your.email@example.com>
;; Author: Vitali Vinahradski <vitali@vinahradski.de>
;; Maintainer: Vitali Vinahradski <vitali@vinahradski.de>
;; Created: May 27, 2025
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.1") (org "9.8") (org-modern "1.7"))
;; Keywords: org, org-modern, org-habit, display, tools
;; URL: https://github.com/connormclaud/org-modern-right-justify

;; This file is not part of GNU Emacs.

;; Licensed under the GPL version 3 or later (GPLv3+); see
;; https://www.gnu.org/licenses/gpl-3.0.en.html

;;; Commentary:
;;
;; This package provides visual enhancements for Org mode, particularly
;; when used with `org-modern`. It includes:
;;
;; 1. Pixel perfect right-alignment of tags in Org Agenda views processed by `org-modern`.
;;    This respects your `org-agenda-tags-column` setting for determining
;;    the alignment reference but always right-aligns.
;;
;;
;;; Code:

(require 'org)
(require 'org-modern)
(require 'org-habit)

;;; Habit Graph Terminator
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar org-modern-right-justify--habit-graph-terminator
  (propertize "\u200B" ; Zero-Width Space
              'invisible t
              'org-modern-right-justify t ; Marker property
              ;; 'intangible t ; Uncomment for increased protection against manual deletion
              )
  "An invisible, zero-width character to terminate org-habit graphs.
This helps prevent accidental deletion of the graph's end and can
stabilize layout in some situations.")

(defun org-modern-right-justify--append-terminator-to-habit-graph (graph-string)
  "Append `org-modern-right-justify--habit-graph-terminator` to GRAPH-STRING.
This function is intended for use as `:filter-return` advice on
`org-habit-build-graph`."
  (if (stringp graph-string)
      (concat graph-string org-modern-right-justify--habit-graph-terminator)
    graph-string)) ; Return original if not a string (robustness)

;;; Habit Graph Padding
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun org-modern-right-justify--pad-habit-lines (&optional _line)
  "Pad habit lines so the consistency graph doesn't overwrite tags.
Inserts spaces before each tag group on habit lines to push tags
past the graph zone.  Uses `indent-to' which is a no-op when tags
are already far enough to the right."
  (let ((inhibit-read-only t)
        (indent-tabs-mode nil)
        (graph-end (+ org-habit-graph-column 1
                      org-habit-preceding-days
                      org-habit-following-days)))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (when (get-text-property (point) 'org-habit-p)
          (end-of-line)
          (when (re-search-backward org-tag-group-re (line-beginning-position) t)
            (goto-char (match-beginning 1))
            (let ((needed (max 0 (- (1+ graph-end) (current-column)))))
              (when (> needed 0)
                (insert (make-string needed ?\s))))))
        (forward-line)))))

;;; Tag Alignment
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun org-modern-right-justify--align-tags (&optional on-current-line-only)
  "Right-align the first encountered (typically rightmost) Org tag group on relevant lines.
If ON-CURRENT-LINE-ONLY is non-nil, operate only on the current line.
Otherwise, operate on all lines from point-min.
This function is based on the user's provided working snippet."
  (let* ((inhibit-read-only t)
         ;; Default to 'auto if org-agenda-tags-column is nil, for robustness.
         (tags-column-setting (or org-agenda-tags-column 'auto))
         (current-org-agenda-tags-column
          (if (eq 'auto tags-column-setting)
              ;; Use selected window for calculating max characters per line.
              (-(window-max-chars-per-line (selected-window)))
            tags-column-setting))
         (start-pos (if on-current-line-only (line-beginning-position) (point-min)))
         ;; `search-boundary` is nil for re-search-forward to mean point-max.
         (search-boundary (if on-current-line-only (line-end-position) nil)))

    (org-fold-core-ignore-modifications
     (save-excursion
       (goto-char start-pos)
       (while (re-search-forward org-tag-group-re search-boundary 'noerror)
         ;; Store current line's end position before buffer modification,
         ;; as inserting/deleting text can affect `(line-end-position)` if point moves.
         (let ((processed-line-end (line-end-position)))
           (let* ((tag-match (match-string 1)) ; The actual tags, e.g., ":TAG1:TAG2:"
                  (tag-len (length tag-match))
                  (tag-pixel-width (string-pixel-width tag-match (current-buffer)))
                  ;; `target-col` is where the tags should effectively start if left-aligned,
                  ;; or the reference for right-alignment margin.
                  (target-col
                   (if (< current-org-agenda-tags-column 0) ; Negative: from right edge
                       (- (abs current-org-agenda-tags-column) tag-len)
                     current-org-agenda-tags-column)) ; Positive: fixed column
                  current-col-before-tags)

             ;; Go to the start of the tag group (e.g., beginning of ":TAG1:")
             (goto-char (match-beginning 1))

             ;; Delete whitespace immediately preceding the tags on this line
             (let ((bol-of-tag-line (line-beginning-position))
                   (tag-original-start-point (point)))
               (save-excursion
                 (goto-char tag-original-start-point)
                 (skip-chars-backward " \t" bol-of-tag-line)
                 (setq current-col-before-tags (current-column))
                 (delete-region (point) tag-original-start-point)))

             ;; Insert leading spaces and the special alignment space.
             ;; The `display` property does the main work.
             (let* ((padding-space-count (max 1 (- target-col current-col-before-tags 2)))
                    (spaces-to-insert (make-string padding-space-count ?\s)))
               (insert spaces-to-insert)
               (insert (propertize " "
                                   'display `(space :align-to (- right (,tag-pixel-width)))
                                   'face 'org-tag ; Attempt to blend with tag face
                                   'org-modern-right-justify t)))) ; Marker property

           ;; Move point to the end of the line that contained the processed tag.
           ;; This ensures the next `re-search-forward` starts searching from the next line
           ;; (or after this point), effectively processing one tag group per line.
           (goto-char processed-line-end)
           ))))))

(defun org-modern-right-justify--advice-align-tags-in-agenda ()
  "Align tags in the current agenda buffer after `org-modern-agenda`.
Processes the whole buffer by calling the core alignment function."
  (org-modern-right-justify--align-tags nil)
  (add-hook 'text-scale-mode-hook
            #'org-modern-right-justify--on-text-scale-change nil t))

(defun org-modern-right-justify--on-text-scale-change ()
  "Re-align tags after text-scale change.
The pixel widths baked into display specs become stale when
text-scale changes, causing tags to be mispositioned."
  (when (derived-mode-p 'org-agenda-mode)
    (org-modern-right-justify--align-tags nil)))

;;; Activation and Deactivation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;###autoload
(defun org-modern-right-justify-activate ()
  "Activate the right justify provided by this package.
This includes right-aligning tags in `org-modern` agenda views
and appending terminators to `org-habit` graphs."
  (interactive)
  (advice-add 'org-modern-agenda :after #'org-modern-right-justify--advice-align-tags-in-agenda)
  (advice-add 'org-habit-build-graph :filter-return #'org-modern-right-justify--append-terminator-to-habit-graph)
  (advice-add 'org-habit-insert-consistency-graphs
              :before #'org-modern-right-justify--pad-habit-lines)
  (message "Org Modern Right Justify activated."))

;;;###autoload
(defun org-modern-right-justify-deactivate ()
  "Deactivate the right justify."
  (interactive)
  (advice-remove 'org-modern-agenda #'org-modern-right-justify--advice-align-tags-in-agenda)
  (advice-remove 'org-habit-build-graph #'org-modern-right-justify--append-terminator-to-habit-graph)
  (advice-remove 'org-habit-insert-consistency-graphs
                 #'org-modern-right-justify--pad-habit-lines)
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (remove-hook 'text-scale-mode-hook
                   #'org-modern-right-justify--on-text-scale-change t)))
  (message "Org Modern Right Justify deactivated."))

;;; Provide Feature
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(provide 'org-modern-right-justify)

