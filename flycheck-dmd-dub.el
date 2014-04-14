;;; flycheck-dmd-dub.el --- Sets flycheck-dmd-include-paths from dub package information

;; Copyright (C) 2014 Atila Neves

;; Author:  Atila Neves <atila.neves@gmail.com>
;; Version: 0.1
;; Package-Requires ((flycheck "0.17"))
;; Keywords: languages
;; URL: http://github.com/atilaneves/flycheck-dmd-dub

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package reads the dub package file, either dub.json or package.json,
;; and automatically sets flycheck-dmd-include-paths so that flycheck
;; syntax checking knows to include the dependent packages.

;; Usage:
;;
;;      (add-hook 'd-mode-hook 'flycheck-dmd-dub-set-include-path)

;;; Code:

(require 'json)
(require 'flycheck)


(defun fldd--dub-pkg-version-to-suffix (version)
  "From dub dependency to suffix for the package directory.
VERSION is what follows the colon in a dub.json file such as
'~master' or '>=1.2.3' and returns the suffix to compose the
directory name with."
  (cond
   ((equal version "~master") "-master") ; e.g. "cerealed": "~master" -> cerealed-master
   ((equal (substring version 1 2) "=") (concat "-" (substring version 2))) ;>= or ==
   (t nil)))

(ert-deftest test-fldd--dub-pkg-version-to-suffix ()
  "Test getting the suffix from the package version"
  (should (equal (fldd--dub-pkg-version-to-suffix "~master") "-master"))
  (should (equal (fldd--dub-pkg-version-to-suffix ">=1.2.3") "-1.2.3"))
  (should (equal (fldd--dub-pkg-version-to-suffix "==2.3.4") "-2.3.4")))


(defun fldd--dub-pkgs-dir ()
  "Return the directory where dub packages are found."
  (if (eq system-type 'windows-nt)
      (concat (getenv "APPDATA") "\\dub\\packages\\")
    "~/.dub/packages/"))


(defun fldd--dub-pkg-to-dir-name (pkg)
  "Return the directory name for a dub package dependency.
PKG is a package name such as 'cerealed': '~master'."
  (let ((pkg-name (car pkg))
        (pkg-suffix (fldd--dub-pkg-version-to-suffix (cdr pkg))))
    (concat (fldd--dub-pkgs-dir) pkg-name pkg-suffix)))

(ert-deftest test-fldd--dub-pkg-to-dir-name ()
  "Test that the directory name from a dub package dependency is correct."
  (if (not (eq system-type 'windows-nt))
      (progn
        (should (equal (fldd--dub-pkg-to-dir-name '("cerealed" . "~master")) "~/.dub/packages/cerealed-master"))
        (should (equal (fldd--dub-pkg-to-dir-name '("cerealed" . ">=3.4.5")) "~/.dub/packages/cerealed-3.4.5")))))


(defun fldd--stringify-car (lst)
  "Transforms the car of LST into a string representation of its symbol."
  (cons (symbol-name (car lst)) (cdr lst)))

(ert-deftest test-fldd--stringify-car ()
  "Test stringifying the car of a list"
  (should (equal (fldd--stringify-car '(foo bar)) '("foo" bar))))


(defun fldd--add-source-dir (dir)
  "Append the source directory to DIR."
  (concat dir "/source"))

(ert-deftest test-fldd--add-source-dir ()
  "Test adding the source dir to the package dir."
  (should (equal (fldd--add-source-dir "~/.dub/packages/vibe-d-master") "~/.dub/packages/vibe-d-master/source")))

(defun fldd--append-source-dirs (dirs)
  "Append version of dir in DIRS with source at the end.
This is done so that standard layout packages are visible."
  (append dirs (mapcar 'fldd--add-source-dir dirs)))

(ert-deftest test-fldd--append-source-dirs ()
  "Test appending source dirs to the original dirs."
  (should (equal (fldd--append-source-dirs
                  '("foo/bar" "baz/boo"))
                 '("foo/bar" "baz/boo" "foo/bar/source" "baz/boo/source"))))


(defun fldd--get-dub-package-dirs-json (json)
  "Return the directories where the packages are for this JSON assoclist."
  (let* ((symbol-dependencies (cdr (assq 'dependencies json)))
         (dependencies (mapcar 'fldd--stringify-car symbol-dependencies)))
    (fldd--append-source-dirs (delq nil (mapcar 'fldd--dub-pkg-to-dir-name dependencies)))))

(ert-deftest test-fldd--get-dub-package-dirs-json ()
  "Test getting the package directories from a json object"
  (should (equal (fldd--get-dub-package-dirs-json (json-read-from-string "{}")) nil))
  (should (equal (fldd--get-dub-package-dirs-json (json-read-from-string "{\"dependencies\": {}}")) nil))
  (should (equal (fldd--get-dub-package-dirs-json (json-read-from-string "{\"dependencies\": {}}")) nil))
  (should (equal (fldd--get-dub-package-dirs-json
                  (json-read-from-string
                   "{\"dependencies\": { \"vibe-d\": \"~master\"}}"))
                 '("~/.dub/packages/vibe-d-master" "~/.dub/packages/vibe-d-master/source")))
  )

(defun fldd--get-dub-package-dirs (dub-json-file)
  "Read DUB-JSON-FILE and get the package directories."
  (fldd--get-dub-package-dirs-json (json-read-file dub-json-file)))



(defun fldd--get-project-dir ()
  "Locates the project directory by searching up for either package.json or dub.json."
  (let ((package-json-dir (locate-dominating-file default-directory "dub.json"))
        (dub-json-dir (locate-dominating-file default-directory "package.json")))
    (or dub-json-dir package-json-dir)))


(defun fldd--get-jsonfile-name(basedir)
  "Return the name of the json file to read given the base directory"
  (let ((dub-json (concat basedir "dub.json")))
    (if (file-exists-p dub-json)
        dub-json
      ;(concat basedir "package.json"))))
      (expand-file-name "package.json" basedir))))


;;;###autoload
(defun flycheck-dmd-dub-set-include-path ()
  "Set `flycheck-dmd-include-path' from dub info if available."
  (let* ((basedir (fldd--get-project-dir))
           (jsonfile (fldd--get-jsonfile-name basedir)))
      (when basedir
        (setq flycheck-dmd-include-path (fldd--get-dub-package-dirs jsonfile)))))



(provide 'flycheck-dmd-dub)
;;; flycheck-dmd-dub ends here
