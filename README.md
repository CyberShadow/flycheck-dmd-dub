flycheck-dmd-dub
================
[![Build Status](https://travis-ci.org/atilaneves/flycheck-dmd-dub.png?branch=master)](https://travis-ci.org/atilaneves/flycheck-dmd-dub)

Emacs lisp to read dependency information from dub and add syntax
highlighting via flycheck that resolves dependencies.

Usage: `(add-hook 'd-mode-hook 'flycheck-dmd-dub-set-include-path)`
