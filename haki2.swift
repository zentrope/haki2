//
// Copyright (c) 2019-present Keith Irwin
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

extension String {
    func trim() -> String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func isInt() -> Bool {
        return Int(self) != nil
    }

    func isDouble() -> Bool {
        return Double(self) != nil
    }
}

// ----------------------------------------------------------------------------

class Reader {
    // Given a bunch of source code, return expressions suitable for
    // lexing.

    enum ReaderError: Error {
        case incompleteForm(startingAt: String)
    }

    private var buffer: String

    init(text: String) {
        buffer = text
    }

    // Initially, read lazily rather than process the entire buffer at
    // once.

    private func read(sourceCode: String) throws -> (String?, String?) {
        if sourceCode.trim().isEmpty {
            return (nil, nil)
        }
        var opens = 0
        var closes = 0
        var form = ""
        for char in sourceCode {
            if char == "(" {
                opens += 1
            }
            if char == ")" {
                closes += 1
            }
            form += String(char)
            if opens > 0, opens == closes {
                break
            }
        }

        if opens != closes {
            throw ReaderError.incompleteForm(startingAt: String(sourceCode.prefix(30)) + "...")
        }

        let remainingSourceCode = String(sourceCode.dropFirst(form.count)).trim()
        return (remainingSourceCode, form.trim())
    }

    func read() throws -> String? {
        let (remaining, form) = try read(sourceCode: buffer)
        buffer = remaining ?? ""
        return form
    }
}

// ----------------------------------------------------------------------------

enum Token {
    case openParen
    case closeParen
    case symbol(String)
    case string(String)
    case integer(String)
    case double(String)
    case quote
}

struct Lexer {
    // Given a valid form (balanced parens), return a vector of typed
    // tokens suitable for parsing.

    static func lex(form: String) -> [Token] {
        var tokens = [Token]()
        var inString = false
        var word = ""

        func appendString() {
            if inString {
                tokens.append(Token.string(word))
            }
            word = ""
            inString = !inString
        }

        func appendWord() {
            word = word.trim()

            if word.isEmpty {
                return
            }

            if word.isInt() {
                tokens.append(Token.integer(word))
            } else if word.isDouble() {
                tokens.append(Token.double(word))
            } else {
                tokens.append(Token.symbol(word))
            }

            word = ""
        }

        form.trim().forEach { char in

            if inString, char != "\"" {
                word += String(char)
                return
            }

            switch char {
            case " ", "\t", "\r", "\n":
                appendWord()

            case ",":
                break

            case "(":
                tokens.append(Token.openParen)

            case ")":
                appendWord()
                tokens.append(Token.closeParen)

            case "\"":
                appendString()

            default:
                word += String(char)
            }
        }
        return tokens
    }
}

// ----------------------------------------------------------------------------

enum Sexp {
    case atom(Token)
    case list([Sexp])

    func getValue() -> String {
        if case let .atom(token) = self {
            switch token {
            case let .symbol(val), let .integer(val), let .string(val), let .double(val):
                return val
            default:
                return "ERROR"
            }
        }
        return "ERROR"
    }

    func toString() -> String {
        switch self {
        case let .atom(token):
            return "\(token)"
        case let .list(values):
            return "[ " + values.map { $0.toString() }.joined(separator: ", ") + " ]"
        }
    }
}

class Parser {
    enum ParseError: Error {
        case unknownToken(token: Token)
    }

    var tokens: [Token]
    var position = 0

    init(_ tokens: [Token]) {
        self.tokens = tokens
    }

    func parse() throws -> Sexp {
        let token = next()

        switch token {
        case Token.openParen:
            return try parseList()
        case Token.symbol, Token.integer, Token.double, Token.string:
            return Sexp.atom(token)
        default:
            throw ParseError.unknownToken(token: token)
        }
    }

    private func pushBack() {
        if position > 0 {
            position -= 1
        }
    }

    private func next() -> Token {
        let token = tokens[position]
        position += 1
        return token
    }

    private func notDone() -> Bool {
        return position + 1 != tokens.count
    }

    private func parseList() throws -> Sexp {
        var list = [Sexp]()

        done: while notDone() {
            let token = next()
            switch token {
            case Token.openParen:
                let subList = try parseList()
                list.append(subList)
            case Token.closeParen:
                break done
            default:
                pushBack()
                let atom = try parse()
                list.append(atom)
            }
        }
        return Sexp.list(list)
    }
}

// ----------------------------------------------------------------------------

class Compiler {
    // Attempts to output sensible Swift from Lisp forms

    var primitives: [String: String] = [
        "+": "Core._plus",
    ]

    func getPrimitive(_ name: String) -> String {
        return primitives[name] ?? name
    }

    func compileDef(_ sexp: Sexp) -> String {
        if case let .list(values) = sexp {
            let name = values[1].getValue()
            let val = values[2]
            var expr = ""
            switch val {
            case .atom:
                expr = val.getValue()
            case .list:
                expr = compileCall(val)
            }
            return "let \(name) = \(expr)"
        }
        return "#ERROR#"
    }

    func compileCall(_ sexp: Sexp) -> String {
        if case let .list(values) = sexp {
            let name = getPrimitive(values[0].getValue())
            let params = values.dropFirst()
                .map {
                    switch $0 {
                    case .atom:
                        return $0.getValue()
                    case .list:
                        return compileCall($0)
                    }

                }.joined(separator: ", ")
            return "\(name)(\(params))"
        }
        return "#ERROR#"
    }

    func compileParams(_ sexp: Sexp) -> String {
        if case let .list(values) = sexp {
            return values.map { "_ \($0.getValue()):Any" }.joined(separator: ", ")
        }
        return "#ERROR#"
    }

    func compileDefun(_ sexp: Sexp) -> String {
        if case let .list(values) = sexp {
            let name = values[1].getValue()
            let params = compileParams(values[2])
            var exprs: [String] = values[3 ..< Array(values).count].map {
                switch $0 {
                case .atom:
                    return "  " + $0.getValue()
                case .list:
                    return "  " + compileCall($0)
                }
            }

            exprs[exprs.count - 1] = "  return " + (exprs.last ?? "nil").trim()
            let body = exprs.joined(separator: "\n")
            return "func \(name) (\(params)) -> Any {\n\(body)\n}"
        }
        return "#ERROR#"
    }

    func compile(_ sexp: Sexp) {
        switch sexp {
        case .atom:
            print("got a token \(sexp.getValue())")
        case let .list(tokens):

            if let atom = tokens.first {
                switch atom {
                case .atom:
                    switch atom.getValue() {
                    case "def":
                        print(compileDef(sexp))
                    case "defun":
                        print(compileDefun(sexp))
                    default:
                        print(compileCall(sexp))
                    }
                case .list:
                    print("can't start with a form with a list")
                }
                return
            }

            print("can't compile sexp")
        }
    }
}

// ----------------------------------------------------------------------------

let core = try String(contentsOfFile: "./core.swift", encoding: .utf8)

let script =
    """
      (def x 23)
      (def y 44.5)

      (defun add (a b)
        (+ a b x y))
      (print (add 1 2))
      (print (add (add 1 2) (+ 3 4)))
    """

func main() {
    print(core)
    do {
        let reader = Reader(text: script)
        while let form = try reader.read() {
            print("  ")
            let tokens = Lexer.lex(form: form)
            let expr = try Parser(tokens).parse()
            let comp = Compiler()
            comp.compile(expr)
        }
    } catch let err {
        print("ERROR: \(err)")
    }
}

// TODO:
//
// Compile to:
//

// struct User {
//     static func main() {
//         print(add(1, 2))
//
//         print(add(add(1, 2), Core._plus(3, 4)))
//         print(z)
//     }
//
//     static let x = 23
//     static let y = 44.5
//     static let z = add(x, y)
//
//     static func add(_ a: Any, _ b: Any) -> Any {
//         return Core._plus(a, b, x, y)
//     }
// }
//
// User.main()

// This allows for future modules, and allows for functions and vars
// to be output in any order. Anything that's not a func or let goes
// into a main function

main()

// Experiments on what some of the code might look like

//// Generated
//
// func add(_ aNum: Any, _ bNum: Any) throws -> Any {
//    return try prim_plus([aNum, bNum])
// }
//
//// Test
//
// do {
//    print(try add(1, 12))
// } catch let err {
//    print("Error: \(err)")
// }
