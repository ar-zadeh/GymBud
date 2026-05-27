import Foundation

// MARK: - BERT WordPiece Tokenizer
//
// Replicates sentence-transformers' default tokenisation for all-MiniLM-L6-v2:
//   1. NFD-decompose + strip combining marks (= strip accents)
//   2. Lowercase + split on whitespace / punctuation / CJK
//   3. WordPiece: longest-match subword segmentation using vocab.txt
//   4. Wrap with [CLS] / [SEP], pad/truncate to maxLength (128)
//
// vocab.txt must be present in the main app bundle (30,522 lines, one token per line).

final class BertTokenizer {
    static let shared = BertTokenizer()

    static let maxLength = 128

    private let vocab:  [String: Int32]
    private let unkID:  Int32 = 100
    private let clsID:  Int32 = 101
    private let sepID:  Int32 = 102
    private let padID:  Int32 = 0

    // MARK: - Public

    struct Encoding {
        let inputIds:      [Int32]   // [maxLength]
        let attentionMask: [Int32]   // [maxLength]
        let tokenTypeIds:  [Int32]   // [maxLength] — all zeros (single sequence)
    }

    /// Tokenize `text` and return fixed-length (maxLength) int32 arrays ready for CoreML.
    func encode(_ text: String) -> Encoding {
        var ids: [Int32] = [clsID]

        for word in basicTokenize(text) {
            ids += wordpieceIDs(word)
            if ids.count >= Self.maxLength - 1 { break }
        }

        // Truncate to leave room for [SEP]
        if ids.count > Self.maxLength - 1 {
            ids = Array(ids.prefix(Self.maxLength - 1))
        }
        ids.append(sepID)

        let realLen = ids.count
        ids += Array(repeating: padID,    count: Self.maxLength - realLen)
        let mask  = (0..<Self.maxLength).map { Int32($0 < realLen ? 1 : 0) }
        let types = Array(repeating: Int32(0), count: Self.maxLength)

        return Encoding(inputIds: ids, attentionMask: mask, tokenTypeIds: types)
    }

    // MARK: - Init

    private init() {
        guard let url = Bundle.main.url(forResource: "vocab", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("BertTokenizer: vocab.txt not found in app bundle — add it to the Xcode target")
        }
        var v: [String: Int32] = [:]
        v.reserveCapacity(30_522)
        var idx: Int32 = 0
        // enumerateLines handles \n, \r\n, and \r, and never includes the terminator
        text.enumerateLines { line, _ in
            if !line.isEmpty { v[line] = idx }
            idx += 1
        }
        vocab = v
    }

    // MARK: - Basic tokenisation

    private func basicTokenize(_ text: String) -> [String] {
        // NFD decompose; this separates base chars from their combining marks
        let nfd = text.lowercased().decomposedStringWithCanonicalMapping
        var processed = ""
        processed.reserveCapacity(nfd.unicodeScalars.count * 2)

        for scalar in nfd.unicodeScalars {
            let cat = scalar.properties.generalCategory
            // Drop combining marks (strips accents like é → e)
            if cat == .nonspacingMark { continue }
            // Surround CJK characters with spaces so they become individual tokens
            if isCJK(scalar.value) {
                processed += " \(Character(scalar)) "
                continue
            }
            // Surround punctuation/symbols with spaces
            if isPunctuationOrSymbol(scalar) {
                processed += " \(Character(scalar)) "
                continue
            }
            processed.unicodeScalars.append(scalar)
        }

        return processed.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    // MARK: - WordPiece

    private func wordpieceIDs(_ token: String) -> [Int32] {
        guard !token.isEmpty else { return [] }
        // Fast path: whole word is in vocab
        if let id = vocab[token] { return [id] }

        let chars = Array(token)
        var result: [Int32] = []
        var start = 0

        while start < chars.count {
            var end = chars.count
            var found: (id: Int32, end: Int)?

            while start < end {
                let sub = start == 0
                    ? String(chars[start..<end])
                    : "##" + String(chars[start..<end])
                if let id = vocab[sub] {
                    found = (id, end)
                    break
                }
                end -= 1
            }

            guard let f = found else { return [unkID] }
            result.append(f.id)
            start = f.end
        }

        return result
    }

    // MARK: - Unicode helpers

    private func isCJK(_ value: UInt32) -> Bool {
        (value >= 0x4E00 && value <= 0x9FFF)   ||
        (value >= 0x3400 && value <= 0x4DBF)   ||
        (value >= 0x20000 && value <= 0x2A6DF) ||
        (value >= 0x2A700 && value <= 0x2B73F) ||
        (value >= 0x2B740 && value <= 0x2B81F) ||
        (value >= 0x2B820 && value <= 0x2CEAF) ||
        (value >= 0xF900 && value <= 0xFAFF)   ||
        (value >= 0x2F800 && value <= 0x2FA1F)
    }

    private func isPunctuationOrSymbol(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        // ASCII punctuation blocks
        if (v >= 33 && v <= 47) || (v >= 58 && v <= 64) ||
           (v >= 91 && v <= 96) || (v >= 123 && v <= 126) { return true }
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation,
             .closePunctuation, .initialPunctuation, .finalPunctuation,
             .otherPunctuation, .mathSymbol, .currencySymbol,
             .modifierSymbol, .otherSymbol:
            return true
        default:
            return false
        }
    }
}
