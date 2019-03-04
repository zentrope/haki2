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

    static func toString(_ sexp: Sexp) -> String {
        switch sexp {
        case let .atom(token):
            return "\(token)"
        case let .list(values):
            return "[ " + values.map { toString($0) }.joined(separator: ", ") + " ]"
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
            position = position - 1
        }
    }

    private func next() -> Token {
        let t = tokens[position]
        position += 1
        return t
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
    func compile(expression _: Sexp) {}
}

// ----------------------------------------------------------------------------

func main() {
    let script = """
      (def x 23)
      (def y 44.5)
      (defun add (a b)
        (+ a b x y))
      (add 1 2)
    """

    do {
        let reader = Reader(text: script)
        while let form = try reader.read() {
            print("form: \(form)")
            let tokens = Lexer.lex(form: form)
            tokens.forEach { token in
                print("  token: `\(token)`")
            }

            let expr = try Parser(tokens).parse()
            print("  expr: `\(Sexp.toString(expr))`")
        }
    } catch let err {
        print("ERROR: \(err)")
    }
}

main()

// Experiments on what some of the code might look like

// enum HakiRuntimeError: Error {
//    case invalidType(expected: String, found: String, value: Any)
// }
//
// func prim_plus(_ numbers: [Any]) throws -> Any {
//    var result: Double = 0.0
//    try numbers.forEach { num in
//        switch num {
//        case let num as Int:
//            result += Double(num)
//        case let dub as Double:
//            result += dub
//        default:
//            throw HakiRuntimeError.invalidType(expected: "Number", found: "\(type(of: num))", value: num)
//        }
//    }
//    if result.rounded(.up) == result {
//        return Int(result)
//    }
//    return result
// }
//
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
