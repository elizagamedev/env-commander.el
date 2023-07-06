;;; env-commander.el --- Per-directory env setup for shell commands -*- lexical-binding:t -*-

;; Copyright (C) 2023  Eliza Velasquez

;; Author: Eliza Velasquez
;; Version: 0.1.0
;; Created: 2023-07-06
;; Package-Requires: ((emacs "28.1"))
;; Keywords: processes unix
;; URL: https://github.com/elizagamedev/env-commander.el
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This program is free software: you can redistribute it and/or modify
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

;; `env-commander-mode' is a simple mode which allows any shell commands that
;; Emacs invokes to run one or more commands beforehand to initialize the shell
;; environment.  There are many Emacs packages which can configure process
;; environments, for example, direnv [1], but they lack the ability to go a step
;; further and define shell functions and aliases, which is often required by
;; "virtual environment" tools.  For those who prefer interacting with shell
;; commands via `shell-command' rather than `shell', `eshell', or `term',
;; `env-commander-mode' is here to assist.
;;
;; `env-commander-mode' operates by exposing an alist
;; `env-commander-commands-alist', which maps directories to lists of
;; environment commands.  See its documentation for details, including an
;; example usage.
;;
;; [1] https://github.com/wbolster/emacs-direnv

;;; Code:

(require 'tramp-sh)

(defgroup env-commander nil
  "Automatically source shell scripts when running shell commands."
  :group 'processes)

(defcustom env-commander-commands-alist nil
  "Alist to match directories to env commands.

When `env-commander-mode' is enabled, any shell command started
by Emacs will first execute the commands corresponding to any
keys which match `default-directory' (expanded via
`expand-file-name').  A directory may match multiple keys.  The
environment commands will be combined, starting with the first
match.

`env-commander-commands-alist' can also accept Tramp paths as
keys.

Consider the following example:

  (customize-set-variable
   \\='env-commander-commands-alist
   \\='((\"^/home/user/project1\"
      . (\"alias foo=/some/contrived/example.sh\"
         \"source ~/project1/env.sh\"))
     (\"^/home/user/project1/subdir\"       ; extra commands for subdir
      . (\"alias bar=/some/other/example.sh\"))
     (\"^/sshx?:remotehost:/home/user/project2/\" ; tramp works too
      . (\"source ~/project2/env.sh\"))))

If the shell command `foo' is run in the directory
\"/home/user/project1/subdir\", `env-commander-mode' will
translate that to the full shell command:

  alias foo=/some/contrived/example.sh;source \\
  ~/project1/env.sh;alias bar=/some/other/example.sh;foo"
  :type '(alist :key-type regexp :value-type (repeat string))
  :risky t
  :group 'env-commander)

(defcustom env-commander-shell-command-separator ";"
  "Separator for shell commands."
  :type 'string
  :risky t
  :group 'env-commander)

(defun env-commander--commands-for-directory (directory)
  "Return env commands from `env-commander-commands-alist'.

DIRECTORY should be the result of `expand-file-name' over
`default-directory'."
  (apply #'append
         (mapcar (lambda (pair)
                   (when (string-match-p (car pair) directory)
                     (cdr pair)))
                 env-commander-commands-alist)))

(defun env-commander--make-process-advice (args)
  "If a shell command, return ARGS modified for env setup.

See `env-commander-commands-alist' for information on this
function's purpose."
  (if-let* ((expanded-default-directory (expand-file-name default-directory))
            (env-commands (env-commander--commands-for-directory
                           expanded-default-directory))
            (new-command
             (when-let* ((command (plist-get args :command))
                         (maybe-shell-file-name (nth 0 command))
                         (maybe-shell-command-switch (nth 1 command))
                         (maybe-shell-command (nth 2 command)))
               (when (and (length= command 3)
                          (string-equal maybe-shell-file-name
                                        shell-file-name)
                          (string-equal maybe-shell-command-switch
                                        shell-command-switch))
                 (list maybe-shell-file-name
                       maybe-shell-command-switch
                       (concat (mapconcat
                                (lambda (env-command)
                                  (concat env-command
                                          env-commander-shell-command-separator))
                                env-commands)
                               maybe-shell-command))))))
      (plist-put args :command new-command)
    args))

;;;###autoload
(define-minor-mode env-commander-mode
  "Automatically source shell scripts when running shell commands."
  :global t
  :group 'env-commander
  (if env-commander-mode
      (progn
        (advice-add #'make-process :filter-args
                    #'env-commander--make-process-advice)
        (advice-add #'tramp-sh-handle-make-process :filter-args
                    #'env-commander--make-process-advice))
    (advice-remove #'make-process
                   #'env-commander--make-process-advice)
    (advice-remove #'tramp-sh-handle-make-process
                   #'env-commander--make-process-advice)))

(provide 'env-commander)

;;; env-commander.el ends here
