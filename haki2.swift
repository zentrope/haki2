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
    static func lex(form: String) -> [TokenType] {
        var tokens = [TokenType]()
        var inString = false
        var word = ""

        func appendString() {
            if inString {
                tokens.append(TokenType.string(word))
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
                tokens.append(TokenType.integer(word))
            } else if word.isDouble() {
                tokens.append(TokenType.double(word))
            } else {
                tokens.append(TokenType.symbol(word))
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
                tokens.append(TokenType.openParen)

            case ")":
                appendWord()
                tokens.append(TokenType.closeParen)

            case "\"":
                appendString()

            default:
                word += String(char)
            }
        }
        return tokens
    }
}

class Reader {
    enum ReaderError: Error {
        case incompleteForm(startingAt: String)
    }

    private var buffer: String

    init(text: String) {
        buffer = text
    }

    // Initially, read lazily rather than process the entire buffer at once.

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
        if let remaining = remaining {
            buffer = remaining
        } else {
            buffer = ""
        }

        return form
    }
}

// ----------------------------------------------------------------------------

func main() {
    let script = """
      (def x 23)
      (def y 44.5)
      (defun add (a b)
        (+ a b "a string", 23, 44.2, a44 "sneaky () string"))
    """

    do {
        let reader = Reader(text: script)
        while let form = try reader.read() {
            print("form: \(form)")
            let tokens = Lexer.lex(form: form)
            tokens.forEach { token in
                print("  token: `\(token)`")
            }
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
