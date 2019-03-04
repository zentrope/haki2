# haki2

Challenge: Make a toy lisp compiler (not interpreter) in Swift, that outputs compilable Swift code.

----

Initial goal is to be able to compile the following to Swift source code:

```lisp
(def x 23)

(def y 44.5)

(defun add (a b)
  (+ a b x y))

(add 1 2)
```

I should be able to:

    $ swiftc generated.swift
    $ ./generated
    $ 70.5

or:

    $ swift generated.swift
    $ 70.5

Surely, once that's accomplished, a fully fledged language is just a few sprints away, _n'est-ce pas_? Given the scoping and memory management built into Swift, I'll have no problems. (Modules? REPL? Shhhh)

## License

Copyright (c) 2019-present Keith Irwin

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published
by the Free Software Foundation, either version 3 of the License,
or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see
[http://www.gnu.org/licenses/](http://www.gnu.org/licenses/).

