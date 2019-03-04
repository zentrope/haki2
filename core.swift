struct Core {
    static func _plus(_ numbers: [Any]) -> Any {
        var result: Double = 0.0
        numbers.forEach { num in
            switch num {
            case let num as Int:
                result += Double(num)
            case let dub as Double:
                result += dub
            default:
                fatalError("expected: Number, found: \(type(of: num))")
            }
        }
        if result.rounded(.up) == result {
            return Int(result)
        }
        return result
    }

    static func _plus(_ numbers: Any...) -> Any {
        return _plus(numbers)
    }
}
