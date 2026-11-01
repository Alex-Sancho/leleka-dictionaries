import Foundation

// **Writes out a Morfologik dictionary as text** — every word form with
// its base form and tags, a line each, separated by tabs:
//
//   dump <file.dict>  >  forms.tsv
//
// Reads the CFSA2 automaton (the format version byte 0xC6, as
// morfologik-fsa writes it; `.info`: separator "+", encoder SUFFIX,
// UTF-8). Each path of the automaton is "form+lemma+tags", the lemma
// written as how many bytes to cut from the form's end (a letter from
// "A") and what to add. Built and run by `build-dictionary.sh` for a
// dictionary from VESUM (`Edition.vesum`).

let arguments = CommandLine.arguments
guard arguments.count == 2, let data = FileManager.default.contents(atPath: arguments[1]) else {
    FileHandle.standardError.write(Data("usage: dump <file.dict>\n".utf8))
    exit(2)
}
let bytes = [UInt8](data)

// The header: "\fsa", the version, the flags (two bytes), the label table.
guard bytes.count > 8, Array(bytes[0..<4]) == Array("\\fsa".utf8), bytes[4] == 0xC6 else {
    FileHandle.standardError.write(Data("✗ not a CFSA2 automaton\n".utf8))
    exit(1)
}
let flags = Int(bytes[5]) << 8 | Int(bytes[6])
let hasNumbers = flags & (1 << 8) != 0
let labelCount = Int(bytes[7])
let labels = Array(bytes[8..<(8 + labelCount)])
let arcs = Array(bytes[(8 + labelCount)...])

let targetNext: UInt8 = 1 << 7
let lastArc: UInt8 = 1 << 6
let finalArc: UInt8 = 1 << 5
let labelIndexMask: UInt8 = (1 << 5) - 1

func readVInt(_ offset: Int) -> Int {
    var offset = offset
    var byte = arcs[offset]
    var value = Int(byte & 0x7F)
    var shift = 7
    while byte & 0x80 != 0 {
        offset += 1
        byte = arcs[offset]
        value |= Int(byte & 0x7F) << shift
        shift += 7
    }
    return value
}

func skipVInt(_ offset: Int) -> Int {
    var offset = offset
    while arcs[offset] & 0x80 != 0 { offset += 1 }
    return offset + 1
}

func firstArc(_ node: Int) -> Int {
    hasNumbers ? skipVInt(node) : node
}

func isLast(_ arc: Int) -> Bool { arcs[arc] & lastArc != 0 }

func skipArc(_ arc: Int) -> Int {
    let flag = arcs[arc]
    var offset = arc + 1
    if flag & labelIndexMask == 0 { offset += 1 }
    if flag & targetNext == 0 { offset = skipVInt(offset) }
    return offset
}

func label(_ arc: Int) -> UInt8 {
    let index = Int(arcs[arc] & labelIndexMask)
    return index > 0 ? labels[index] : arcs[arc + 1]
}

/// Where an arc leads: with "target next", the byte after the node's
/// last arc; otherwise an address written after the label. 0 — nowhere.
func destination(_ arc: Int) -> Int {
    if arcs[arc] & targetNext != 0 {
        var last = arc
        while !isLast(last) { last = skipArc(last) }
        return skipArc(last)
    }
    return readVInt(arc + (arcs[arc] & labelIndexMask == 0 ? 2 : 1))
}

let separator = UInt8(ascii: "+")
var output = FileHandle.standardOutput
var buffer = Data()

/// One path: "form+lemma+tags" → "form\tlemma\ttags\n".
func emit(_ path: [UInt8]) {
    guard let first = path.firstIndex(of: separator),
          let second = path[(first + 1)...].firstIndex(of: separator)
    else { return }
    let form = Array(path[..<first])
    let encoded = Array(path[(first + 1)..<second])
    let tags = Array(path[(second + 1)...])
    guard let code = encoded.first else { return }
    let cut = Int(code &- UInt8(ascii: "A"))
    let lemma = (cut == 255 ? [] : Array(form.dropLast(min(cut, form.count)))) + encoded.dropFirst()
    buffer.append(contentsOf: form)
    buffer.append(UInt8(ascii: "\t"))
    buffer.append(contentsOf: lemma)
    buffer.append(UInt8(ascii: "\t"))
    buffer.append(contentsOf: tags)
    buffer.append(UInt8(ascii: "\n"))
    if buffer.count > 1 << 20 {
        output.write(buffer)
        buffer.removeAll(keepingCapacity: true)
    }
}

// Every path from the root, depth first, without recursion: the stack
// holds the arc to follow next at each depth.
let root = destination(firstArc(0))
var path: [UInt8] = []
var stack: [Int] = [firstArc(root)]
while let arc = stack.last {
    path.append(label(arc))
    if arcs[arc] & finalArc != 0 { emit(path) }
    let next = destination(arc)
    if next != 0 {
        stack.append(firstArc(next))
        continue
    }
    // A dead end: back up to the nearest arc that has a sibling.
    while let top = stack.last {
        path.removeLast()
        stack.removeLast()
        if !isLast(top) {
            stack.append(skipArc(top))
            break
        }
    }
}
output.write(buffer)
