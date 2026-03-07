;;; test-pad-habit.el --- Batch test for habit line padding  -*- lexical-binding: t; -*-
;;
;; Run: emacs --batch -l test-pad-habit.el
;;

(let ((elpaca-builds (expand-file-name "~/.config/emacs/elpaca/builds/")))
  (dolist (pkg '("org" "org-modern" "compat"))
    (let ((dir (expand-file-name pkg elpaca-builds)))
      (when (file-directory-p dir)
        (add-to-list 'load-path dir)))))

(add-to-list 'load-path "/home/connormclaud/source/org-modern-right-justify")

(require 'org)
(require 'org-habit)
(require 'org-modern-right-justify)

(defvar test-pass 0)
(defvar test-fail 0)

(defun test-assert (name expected actual)
  (if (equal expected actual)
      (progn (message "  PASS: %s" name)
             (cl-incf test-pass))
    (message "  FAIL: %s\n    expected: %S\n    actual:   %S" name expected actual)
    (cl-incf test-fail)))

(defun make-test-buffer (lines)
  "Create a temp buffer with LINES.  Each line is (TEXT HABIT-P).
HABIT-P non-nil sets the org-habit-p text property at BOL."
  (let ((buf (generate-new-buffer " *test-pad*")))
    (with-current-buffer buf
      (dolist (spec lines)
        (let ((text (car spec))
              (habit-p (cadr spec))
              (start (point)))
          (insert text "\n")
          (when habit-p
            (put-text-property start (1+ start) 'org-habit-p t)))))
    buf))

(defun buf-lines (buf)
  "Return list of line strings from BUF (without trailing newlines)."
  (with-current-buffer buf
    (split-string (buffer-substring-no-properties (point-min) (point-max)) "\n" t)))

;; Use default org-habit values
(setq org-habit-graph-column 50
      org-habit-preceding-days 21
      org-habit-following-days 7)

;; graph-end = 50 + 1 + 21 + 7 = 79; padding target = graph-end + 1 = 80

(message "=== Test 1: Habit line with tags in graph zone (col 60) ===")
(let* ((task-text "  habit:  Meditate daily")               ;; ~24 chars
       (padding (make-string (- 60 (length task-text)) ?\s)) ;; pad to col 60
       (line (concat task-text padding ":work:"))
       (buf (make-test-buffer (list (list line t)))))
  (with-current-buffer buf
    (org-modern-right-justify--pad-habit-lines)
    (goto-char (point-min))
    (let* ((content (buffer-substring-no-properties (point) (line-end-position)))
           (tag-pos (string-match ":work:" content)))
      (test-assert "tags pushed to col 80" 80 tag-pos)
      (test-assert "no chars before col 50 changed"
                   task-text
                   (substring content 0 (length task-text)))))
  (kill-buffer buf))

(message "=== Test 2: Habit line with tags past graph-end (col 100) ===")
(let* ((task-text "  habit:  Meditate daily")
       (padding (make-string (- 100 (length task-text)) ?\s))
       (line (concat task-text padding ":health:"))
       (buf (make-test-buffer (list (list line t)))))
  (with-current-buffer buf
    (org-modern-right-justify--pad-habit-lines)
    (goto-char (point-min))
    (let* ((content (buffer-substring-no-properties (point) (line-end-position)))
           (tag-pos (string-match ":health:" content)))
      (test-assert "tags stay at col 100 (no-op, already past graph-end+1)" 100 tag-pos)))
  (kill-buffer buf))

(message "=== Test 3: Non-habit line with tags — must be untouched ===")
(let* ((line "  TODO  Some regular task                    :urgent:")
       (buf (make-test-buffer (list (list line nil)))))
  (with-current-buffer buf
    (let ((before (buffer-string)))
      (org-modern-right-justify--pad-habit-lines)
      (test-assert "buffer unchanged" before (buffer-string))))
  (kill-buffer buf))

(message "=== Test 4: Habit line without tags — must be untouched ===")
(let* ((line "  habit:  Meditate daily")
       (buf (make-test-buffer (list (list line t)))))
  (with-current-buffer buf
    (let ((before (buffer-string)))
      (org-modern-right-justify--pad-habit-lines)
      (test-assert "buffer unchanged" before (buffer-string))))
  (kill-buffer buf))

(message "=== Test 5: Mixed buffer ===")
(let* ((habit-line (concat "  habit:  Exercise" (make-string (- 55 18) ?\s) ":gym:"))
       (normal-line "  TODO  Read a book                         :reading:")
       (buf (make-test-buffer (list (list habit-line t)
                                    (list normal-line nil)))))
  (with-current-buffer buf
    (org-modern-right-justify--pad-habit-lines)
    (let ((lines (buf-lines (current-buffer))))
      (test-assert "habit tags at col 80"
                   80 (string-match ":gym:" (nth 0 lines)))
      (test-assert "normal line unchanged"
                   normal-line (nth 1 lines))))
  (kill-buffer buf))

(message "=== Test 6: Tags BEFORE graph column (col 40) — must still be pushed ===")
(let* ((task-text "  personal:  TODO Weekly GTD review")    ;; ~35 chars
       (padding (make-string (- 40 (length task-text)) ?\s))
       (line (concat task-text padding ":Personal:gtd::important:checklist:"))
       (buf (make-test-buffer (list (list line t)))))
  (with-current-buffer buf
    (org-modern-right-justify--pad-habit-lines)
    (goto-char (point-min))
    (let* ((content (buffer-substring-no-properties (point) (line-end-position)))
           (tag-pos (string-match ":Personal:" content)))
      (test-assert "tags pushed to col 80" 80 tag-pos)))
  (kill-buffer buf))

(message "=== Test 7: Tags at exactly graph-column (col 50) ===")
(let* ((task-text "  habit:  Meditate daily")
       (padding (make-string (- 50 (length task-text)) ?\s))
       (line (concat task-text padding ":health:focus:"))
       (buf (make-test-buffer (list (list line t)))))
  (with-current-buffer buf
    (org-modern-right-justify--pad-habit-lines)
    (goto-char (point-min))
    (let* ((content (buffer-substring-no-properties (point) (line-end-position)))
           (tag-pos (string-match ":health:focus:" content)))
      (test-assert "tags pushed to col 80" 80 tag-pos)))
  (kill-buffer buf))

(message "\n=== Results: %d passed, %d failed ===" test-pass test-fail)
(kill-emacs (if (> test-fail 0) 1 0))
