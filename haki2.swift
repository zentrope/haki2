//
// Copyright (c) 2019-present Keith Irwin
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see
// <http://www.gnu.org/licenses/>.
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

enum TokenType {
    case openParen
    case closeParen
    case symbol(String)
    case string(String)
    case integer(String)
    case double(String)
    case quote
}

class Lexer {
    private var tokens = [TokenType]()
    private var inString = false
    private var word = ""

    func lex(form: String) -> [TokenType] {
        reset()
        form.trim().forEach { char in

            if inString, char != "\"" {
                appendChar(char)
                return
            }

            switch char {
            case " ", "\t", "\r", "\n":
                appendWord()

            case ",":
                break

            case "(":
                startList()

            case ")":
                appendWord()
                endList()

            case "\"":
                appendString()

            default:
                appendChar(char)
            }
        }
        return tokens
    }

    private func reset() {
        tokens = [TokenType]()
        inString = false
        word = ""
    }

    private func startList() {
        tokens.append(TokenType.openParen)
    }

    private func endList() {
        tokens.append(TokenType.closeParen)
    }

    private func appendChar(_ char: Character) {
        word += String(char)
    }

    private func appendString() {
        if inString {
            tokens.append(TokenType.string(word))
        }
        word = ""
        inString = !inString
    }

    private func appendWord() {
        word = word.trim()

        if word.isEmpty {
            return
        }

        if word.isInt() {
            tokens.append(TokenType.integer(word))
        } else if word.isDouble() {
            tokens.append(TokenType.double(word))
        } else {
            tokens.append(TokenType.symbol(word))
        }

        word = ""
    }
}

class Reader {
    private var buffer: String

    init(text: String) {
        buffer = text
    }

    func parse() -> [String] {
        return parse(sourceCode: buffer, forms: [])
    }

    private func parse(sourceCode: String, forms: [String]) -> [String] {
        if sourceCode.trim().isEmpty {
            return forms
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

        let remainingSourceCode = String(sourceCode.dropFirst(form.count)).trim()
        let currentForms = forms + [form.trim()]

        return parse(sourceCode: remainingSourceCode, forms: currentForms)
    }
}

// ----------------------------------------------------------------------------

let script = """
  (def x 23)
  (def y 44.5)
  (defun add (a b)
    (+ a b "a string", 23, 44.2, a44 "sneaky () string"))
"""

let reader = Reader(text: script)
let forms = reader.parse()

let lexer = Lexer()
for form in forms {
    print("form: \(form)")
    let tokens = lexer.lex(form: form)
    tokens.forEach { token in
        print("  token: `\(token)`")
    }
}

// print(forms)
// let lexer = Lexer()
// let tokens = lexer.lex(form: script)
// print(script)
//tokens.forEach { token in
//    print("token: `\(token)`")
// }

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
