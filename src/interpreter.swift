import Foundation

let arguments = CommandLine.arguments

guard arguments.count == 5 else {
    print("Использование: interpreter.swift <программа.bin> <дамп.json> <начало> <конец>")
    exit(1)
}

let inputPath = arguments[1]
let dumpPath = arguments[2]

guard let startAddress = Int(arguments[3]),
      let endAddress = Int(arguments[4]),
      startAddress >= 0,
      startAddress <= endAddress else {
    print("Укажи диапазон адресов в формате: 0 <= начало <= конец")
    exit(1)
}

let bytes: [UInt8]

do {
    bytes = Array(try Data(contentsOf: URL(fileURLWithPath: inputPath)))
} catch {
    print("Не удалось прочитать \(inputPath): \(error.localizedDescription)")
    exit(1)
}

var offset = 0
var accumulator = 0
var memory: [Int: Int] = [:]

while offset < bytes.count {
    let opcode = bytes[offset] & 0b111
    let format: (name: String, byteCount: Int, operandBits: Int)

    switch opcode {
    case 0:
        format = ("LOAD", 4, 26)
    case 2:
        format = ("READ", 3, 14)
    case 6:
        format = ("WRITE", 3, 21)
    case 1:
        format = ("SGN", 3, 21)
    default:
        print("Байт \(offset): неизвестный код операции \(opcode)")
        exit(1)
    }

    guard bytes.count - offset >= format.byteCount else {
        print("Байт \(offset): команда \(format.name) записана не полностью")
        exit(1)
    }

    var word: UInt32 = 0
    for index in 0..<format.byteCount {
        word |= UInt32(bytes[offset + index]) << (index * 8)
    }

    let operandMask = (UInt32(1) << format.operandBits) - 1
    let argument = Int((word >> 3) & operandMask)

    switch opcode {
    case 0:
        accumulator = argument
    case 2:
        let address = accumulator + argument
        accumulator = memory[address, default: 0]
    case 6:
        memory[argument] = accumulator
    default:
        print("Команда \(format.name) будет реализована на этапе 4")
        exit(1)
    }

    offset += format.byteCount
}

var dump: [String: Int] = [:]
for address in startAddress...endAddress {
    dump[String(address)] = memory[address, default: 0]
}

do {
    let json = try JSONSerialization.data(withJSONObject: dump, options: [.prettyPrinted, .sortedKeys])
    try json.write(to: URL(fileURLWithPath: dumpPath), options: .atomic)
    print("Дамп памяти сохранён в \(dumpPath)")
} catch {
    print("Не удалось сохранить дамп \(dumpPath): \(error.localizedDescription)")
    exit(1)
}