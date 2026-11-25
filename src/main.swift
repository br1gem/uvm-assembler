import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())

guard arguments.count == 2 || (arguments.count == 3 && arguments[2] == "--test") else {
    print("Использование: ./run.sh <исходник.asm> <результат.bin> [--test]")
    exit(1)
}

let inputPath = arguments[0]
let outputPath = arguments[1]
let testMode = arguments.count == 3

do {
    let source = try String(contentsOfFile: inputPath, encoding: .utf8)
    let lines = source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
    var instructions: [(a: Int, b: Int)] = []

    for (index, line) in lines.enumerated() {
        let lineNumber = index + 1
        let parts = line.split(whereSeparator: \.isWhitespace)

        if parts.isEmpty {
            continue
        }

        guard parts.count == 2, let operand = Int(parts[1]) else {
            print("Строка \(lineNumber): ожидалась команда с целым числом")
            exit(1)
        }

        let mnemonic = parts[0]
        let opcode: Int

        switch mnemonic {
        case "LOAD":
            opcode = 0
        case "READ":
            opcode = 2
        case "WRITE":
            opcode = 6
        case "SGN":
            opcode = 1
        default:
            print("Строка \(lineNumber): неизвестная команда \(mnemonic)")
            exit(1)
        }

        instructions.append((a: opcode, b: operand))
    }

    if testMode {
        for instruction in instructions {
            print("(A=\(instruction.a), B=\(instruction.b))")
        }
    }
} catch {
    print("Не удалось прочитать \(inputPath): \(error.localizedDescription)")
    exit(1)
}