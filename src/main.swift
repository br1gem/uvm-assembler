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

        let limit = UInt32(1) << format.operandBits
        guard let operand = UInt32(exactly: instruction.b), operand < limit else {
            print("Операнд \(instruction.b) должен быть в диапазоне от 0 до \(limit - 1)")
            exit(1)
        }

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

} catch {
    print("Не удалось прочитать \(inputPath): \(error.localizedDescription)")
    exit(1)
}