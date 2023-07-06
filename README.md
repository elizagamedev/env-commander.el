# env-commander.el

`env-commander-mode` is a simple mode which allows any shell commands that Emacs
invokes to run one or more commands beforehand to initialize the shell
environment. There are many Emacs packages which can configure process
environments, for example, [direnv](https://github.com/wbolster/emacs-direnv),
but they lack the ability to go a step further and define shell functions and
aliases, which is often required by "virtual environment" tools. For those who
prefer interacting with shell commands via `shell-command` rather than `shell`,
`eshell`, or `term`, `env-commander-mode` is here to assist.

## Installing

This package is not yet available on M?ELPA. In the meantime, you can use
something like [straight.el](https://github.com/radian-software/straight.el) or
[elpaca.el](https://github.com/progfolio/elpaca). Here is an example with elpaca
and [use-package.el](https://github.com/jwiegley/use-package):

```elisp
(use-package env-commander
  :elpaca (:host github :repo "elizagamedev/env-commander.el")
  :init
  (env-commander-mode 1))
```

## Configuration

`env-commander-mode` operates by exposing an alist
`env-commander-commands-alist`, which maps directories to lists of environment
commands.

Consider the following example:

```elisp
(customize-set-variable
 'env-commander-commands-alist
 '(("^/home/user/project1"
    . ("alias foo=/some/contrived/example.sh"
       "source ~/project1/env.sh"))
   ("^/home/user/project1/subdir"       ; extra commands for subdir
    . ("alias bar=/some/other/example.sh"))
   ("^/sshx?:remotehost:/home/user/project2/" ; tramp works too
    . ("source ~/project2/env.sh"))))
```

If the shell command `foo` is run in the directory "/home/user/project1/subdir",
`env-commander-mode` will translate that to the full shell command:

```shell
alias foo=/some/contrived/example.sh;source ~/project1/env.sh;alias bar=/some/other/example.sh;foo
```
