import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())

guard arguments.count == 2 || (arguments.count == 3 && arguments[2] == "--test") else {
    print("Использование: ./run.sh <исходник.asm> <результат.bin> [--test]")
    exit(1)
}

let inputPath = arguments[0]
let outputPath = arguments[1]
let testMode = arguments.count == 3

let source: String

do {
    source = try String(contentsOfFile: inputPath, encoding: .utf8)
} catch {
    print("Не удалось прочитать \(inputPath): \(error.localizedDescription)")
    exit(1)
}

let lines = source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
var instructions: [(a: Int, b: Int, lineNumber: Int)] = []

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

    let opcode: Int

    switch parts[0] {
    case "LOAD":
        opcode = 0
    case "READ":
        opcode = 2
    case "WRITE":
        opcode = 6
    case "SGN":
        opcode = 1
    default:
        print("Строка \(lineNumber): неизвестная команда \(parts[0])")
        exit(1)
    }

    instructions.append((a: opcode, b: operand, lineNumber: lineNumber))
}

var encodedInstructions: [[UInt8]] = []

for instruction in instructions {
    let format: (byteCount: Int, operandBits: Int)

    switch instruction.a {
    case 0:
        format = (4, 26)
    case 2:
        format = (3, 14)
    case 6, 1:
        format = (3, 21)
    default:
        print("Неизвестный код операции: \(instruction.a)")
        exit(1)
    }

    let limit = 1 << format.operandBits
    let minimum = instruction.a == 0 ? -(limit / 2) : 0
    let maximum = minimum + limit - 1

    guard (minimum...maximum).contains(instruction.b) else {
        print("Строка \(instruction.lineNumber): операнд \(instruction.b) вне диапазона \(minimum)...\(maximum)")
        exit(1)
    }

    let operandMask = UInt32(limit - 1)
    let operand = UInt32(truncatingIfNeeded: instruction.b) & operandMask
    let word = (operand << 3) | UInt32(instruction.a)

    let bytes = (0..<format.byteCount).map { index in
        UInt8(truncatingIfNeeded: word >> (index * 8))
    }
    encodedInstructions.append(bytes)
}

let machineCode = Data(encodedInstructions.joined())

do {
    try machineCode.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
} catch {
    print("Не удалось записать \(outputPath): \(error.localizedDescription)")
    exit(1)
}

print("Ассемблировано команд: \(encodedInstructions.count)")

if testMode {
    for bytes in encodedInstructions {
        let hex = bytes.map { String(format: "0x%02X", UInt32($0)) }
        print(hex.joined(separator: ", "))
    }
}