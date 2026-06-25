import Foundation

private let richMessageConstructor: Int32 = -1158439541
private let vectorConstructor: Int32 = 481674261

func parseRichMessageFallbackText(reader: BufferReader, signature: Int32) -> String? {
    guard signature == richMessageConstructor else {
        telegramApiLog("Unexpected rich message constructor \(String(UInt32(bitPattern: signature), radix: 16, uppercase: false))")
        return nil
    }
    guard reader.readInt32() != nil else {
        return nil
    }
    guard let blocks = parseRichMessageBlockVectorText(reader: reader) else {
        return nil
    }
    guard consumeApiObjectVector(reader: reader, elementType: Api.Photo.self) else {
        return nil
    }
    guard consumeApiObjectVector(reader: reader, elementType: Api.Document.self) else {
        return nil
    }
    return joinRichMessageLines(blocks)
}

func mergeRichMessageFallback(message: String, fallback: String) -> String {
    let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedMessage.isEmpty || trimmedFallback.contains(trimmedMessage) {
        return fallback
    }
    if trimmedFallback.isEmpty {
        return message
    }
    return joinRichMessageLines([message, fallback])
}

private func consumeApiObjectVector<T>(reader: BufferReader, elementType: T.Type) -> Bool {
    guard reader.readInt32() != nil else {
        return false
    }
    return Api.parseVector(reader, elementSignature: 0, elementType: elementType) != nil
}

private func parseRichMessageBlockVectorText(reader: BufferReader) -> [String]? {
    guard reader.readInt32() == vectorConstructor, let count = reader.readInt32() else {
        return nil
    }
    var result: [String] = []
    for _ in 0 ..< count {
        guard let signature = reader.readInt32(), let text = parseRichMessageBlockText(reader: reader, signature: signature) else {
            return nil
        }
        if !text.isEmpty {
            result.append(text)
        }
    }
    return result
}

private func parseRichTextVectorText(reader: BufferReader) -> [String]? {
    guard reader.readInt32() == vectorConstructor, let count = reader.readInt32() else {
        return nil
    }
    var result: [String] = []
    for _ in 0 ..< count {
        guard let signature = reader.readInt32(), let text = parseRichTextFallbackText(reader: reader, signature: signature) else {
            return nil
        }
        result.append(text)
    }
    return result
}

private func parseRichTextChild(reader: BufferReader) -> String? {
    guard let signature = reader.readInt32() else {
        return nil
    }
    return parseRichTextFallbackText(reader: reader, signature: signature)
}

private func parseRichTextFallbackText(reader: BufferReader, signature: Int32) -> String? {
    switch signature {
    case -599948721:
        return ""
    case 1950782688:
        return parseString(reader)
    case 2120376535:
        return parseRichTextVectorText(reader: reader)?.joined()
    case 894777186:
        guard let text = parseRichTextChild(reader: reader), parseString(reader) != nil else {
            return nil
        }
        return text
    case -564523562, 1009288385:
        guard let text = parseRichTextChild(reader: reader), let fallback = parseString(reader) else {
            return nil
        }
        if signature == 1009288385, reader.readInt64() == nil {
            return nil
        }
        return text.isEmpty ? fallback : text
    case 27917308:
        guard let text = parseRichTextChild(reader: reader), reader.readInt64() != nil else {
            return nil
        }
        return text
    case -1514906069:
        guard reader.readInt32() != nil, let text = parseRichTextChild(reader: reader), reader.readInt32() != nil else {
            return nil
        }
        return text
    case 136105807:
        guard reader.readInt64() != nil, reader.readInt32() != nil, reader.readInt32() != nil else {
            return nil
        }
        return ""
    case -1570679104:
        guard reader.readInt64() != nil, let alt = parseString(reader) else {
            return nil
        }
        return alt
    case -1657885545:
        guard let source = parseString(reader) else {
            return nil
        }
        return source
    case 1730456516, -653089380, -1054465340, -1678197867, 1816074681, 55281185,
         -311786236, -939827711, -984177571, 616720265, -1402305622, -1185513171,
         50276819, 2073958401, 1368728810, -853225660, 1277844834:
        return parseRichTextChild(reader: reader)
    case 483104362:
        guard let text = parseRichTextChild(reader: reader), let fallback = parseString(reader) else {
            return nil
        }
        return text.isEmpty ? fallback : text
    default:
        telegramApiLog("Unsupported rich text constructor \(String(UInt32(bitPattern: signature), radix: 16, uppercase: false))")
        return nil
    }
}

private func parsePageCaptionFallbackText(reader: BufferReader) -> String? {
    guard reader.readInt32() == 1869903447 else {
        return nil
    }
    guard let text = parseRichTextChild(reader: reader), let credit = parseRichTextChild(reader: reader) else {
        return nil
    }
    return joinRichMessageLines([text, credit])
}

private func parsePageListItems(reader: BufferReader, ordered: Bool) -> [String]? {
    guard reader.readInt32() == vectorConstructor, let count = reader.readInt32() else {
        return nil
    }
    var result: [String] = []
    for index in 0 ..< count {
        guard let signature = reader.readInt32() else {
            return nil
        }
        let text: String?
        var orderedLabel: String?
        switch signature {
        case -1188055347:
            text = parseRichTextChild(reader: reader)
        case 635466748:
            text = parseRichMessageBlockVectorText(reader: reader).map(joinRichMessageLines)
        case 794323004:
            guard reader.readInt32() != nil else {
                return nil
            }
            text = parseRichTextChild(reader: reader)
        case 1674209194:
            guard reader.readInt32() != nil else {
                return nil
            }
            text = parseRichMessageBlockVectorText(reader: reader).map(joinRichMessageLines)
        case 1577484359:
            guard let num = parseString(reader) else {
                return nil
            }
            orderedLabel = num
            text = parseRichTextChild(reader: reader)
        case -1730311882:
            guard let num = parseString(reader) else {
                return nil
            }
            orderedLabel = num
            text = parseRichMessageBlockVectorText(reader: reader).map(joinRichMessageLines)
        case 352522633:
            guard let flags = reader.readInt32() else {
                return nil
            }
            if Int(flags) & Int(1 << 2) != 0 {
                guard let num = parseString(reader) else {
                    return nil
                }
                orderedLabel = num
            }
            text = parseRichTextChild(reader: reader)
            if Int(flags) & Int(1 << 3) != 0 {
                guard let value = reader.readInt32() else {
                    return nil
                }
                if orderedLabel == nil {
                    orderedLabel = "\(value)"
                }
            }
            if Int(flags) & Int(1 << 4) != 0, parseString(reader) == nil {
                return nil
            }
        case -1879910928:
            guard let flags = reader.readInt32() else {
                return nil
            }
            if Int(flags) & Int(1 << 2) != 0 {
                guard let num = parseString(reader) else {
                    return nil
                }
                orderedLabel = num
            }
            text = parseRichMessageBlockVectorText(reader: reader).map(joinRichMessageLines)
            if Int(flags) & Int(1 << 3) != 0 {
                guard let value = reader.readInt32() else {
                    return nil
                }
                if orderedLabel == nil {
                    orderedLabel = "\(value)"
                }
            }
            if Int(flags) & Int(1 << 4) != 0, parseString(reader) == nil {
                return nil
            }
        default:
            telegramApiLog("Unsupported rich list item constructor \(String(UInt32(bitPattern: signature), radix: 16, uppercase: false))")
            return nil
        }
        guard let itemText = text else {
            return nil
        }
        if !itemText.isEmpty {
            let prefix = orderedLabel.flatMap { $0.isEmpty ? nil : $0 } ?? "\(index + 1)."
            result.append(ordered ? "\(prefix) \(itemText)" : "- \(itemText)")
        }
    }
    return result
}

private func parsePageTableRows(reader: BufferReader) -> [[String]]? {
    guard reader.readInt32() == vectorConstructor, let rowCount = reader.readInt32() else {
        return nil
    }
    var rows: [[String]] = []
    for _ in 0 ..< rowCount {
        guard reader.readInt32() == -524237339 else {
            return nil
        }
        guard reader.readInt32() == vectorConstructor, let cellCount = reader.readInt32() else {
            return nil
        }
        var cells: [String] = []
        for _ in 0 ..< cellCount {
            guard reader.readInt32() == 878078826, let flags = reader.readInt32() else {
                return nil
            }
            let text: String
            if Int(flags) & Int(1 << 7) != 0 {
                guard let cellText = parseRichTextChild(reader: reader) else {
                    return nil
                }
                text = cellText
            } else {
                text = ""
            }
            if Int(flags) & Int(1 << 1) != 0, reader.readInt32() == nil {
                return nil
            }
            if Int(flags) & Int(1 << 2) != 0, reader.readInt32() == nil {
                return nil
            }
            cells.append(text.replacingOccurrences(of: "\n", with: " "))
        }
        rows.append(cells)
    }
    return rows
}

private func parseRichMessageBlockText(reader: BufferReader, signature: Int32) -> String? {
    switch signature {
    case -837994576:
        return parseString(reader).map { _ in "" }
    case 1890305021, -1879401953, -1076861716, -248793375, 1216809369, 504660880,
         -1157691601, 158018284, 1743204781, -1254983893, -608277398, 1747599785:
        return parseRichTextChild(reader: reader)
    case 1182402406:
        return parseRichTextChild(reader: reader)
    case -1066346178:
        guard let text = parseRichTextChild(reader: reader), parseString(reader) != nil else {
            return nil
        }
        return text
    case -618614392:
        return "---"
    case 641563686, 1329878739:
        guard let text = parseRichTextChild(reader: reader), let caption = parseRichTextChild(reader: reader) else {
            return nil
        }
        return joinRichMessageLines([quoteRichMessageText(text), caption])
    case 242108356:
        guard let blocks = parseRichMessageBlockVectorText(reader: reader), let caption = parseRichTextChild(reader: reader) else {
            return nil
        }
        return joinRichMessageLines([quoteRichMessageText(joinRichMessageLines(blocks)), caption])
    case 1987480557:
        guard reader.readInt32() != nil, let blocks = parseRichMessageBlockVectorText(reader: reader), let title = parseRichTextChild(reader: reader) else {
            return nil
        }
        return joinRichMessageLines([title, joinRichMessageLines(blocks)])
    case -454524911:
        return parsePageListItems(reader: reader, ordered: false).map(joinRichMessageLines)
    case -1702174239:
        return parsePageListItems(reader: reader, ordered: true).map(joinRichMessageLines)
    case 534181569:
        guard let flags = reader.readInt32(), let items = parsePageListItems(reader: reader, ordered: true) else {
            return nil
        }
        if Int(flags) & Int(1 << 0) != 0, reader.readInt32() == nil {
            return nil
        }
        if Int(flags) & Int(1 << 1) != 0, parseString(reader) == nil {
            return nil
        }
        return joinRichMessageLines(items)
    case -1085412734:
        guard reader.readInt32() != nil, let title = parseRichTextChild(reader: reader), let rows = parsePageTableRows(reader: reader) else {
            return nil
        }
        let rowText = rows.map { $0.joined(separator: " | ") }
        return joinRichMessageLines([title] + rowText)
    case 1493699616:
        return parseString(reader)
    case 1009361890:
        return parseRichTextChild(reader: reader)
    case 324435594:
        return ""
    case 972174080:
        guard let nestedSignature = reader.readInt32() else {
            return nil
        }
        return parseRichMessageBlockText(reader: reader, signature: nestedSignature)
    case 1705048653, 52401552:
        guard let blocks = parseRichMessageBlockVectorText(reader: reader), let caption = parsePageCaptionFallbackText(reader: reader) else {
            return nil
        }
        return joinRichMessageLines(blocks + [caption])
    case -2143067670:
        guard reader.readInt64() != nil else {
            return nil
        }
        return parsePageCaptionFallbackText(reader: reader)
    case 391759200:
        guard let flags = reader.readInt32(), reader.readInt64() != nil, let caption = parsePageCaptionFallbackText(reader: reader) else {
            return nil
        }
        if Int(flags) & Int(1 << 0) != 0 {
            guard parseString(reader) != nil, reader.readInt64() != nil else {
                return nil
            }
        }
        return caption
    case 2089805750:
        guard reader.readInt32() != nil, reader.readInt64() != nil else {
            return nil
        }
        return parsePageCaptionFallbackText(reader: reader)
    case -1162877472:
        guard let author = parseRichTextChild(reader: reader), reader.readInt32() != nil else {
            return nil
        }
        return author
    case -283684427:
        guard let chatSignature = reader.readInt32(), Api.parse(reader, signature: chatSignature) as? Api.Chat != nil else {
            return nil
        }
        return ""
    case -1468953147:
        guard let flags = reader.readInt32() else {
            return nil
        }
        if Int(flags) & Int(1 << 1) != 0, parseString(reader) == nil {
            return nil
        }
        if Int(flags) & Int(1 << 2) != 0, parseString(reader) == nil {
            return nil
        }
        if Int(flags) & Int(1 << 4) != 0, reader.readInt64() == nil {
            return nil
        }
        if Int(flags) & Int(1 << 5) != 0, (reader.readInt32() == nil || reader.readInt32() == nil) {
            return nil
        }
        return parsePageCaptionFallbackText(reader: reader)
    case -229005301:
        guard parseString(reader) != nil, reader.readInt64() != nil, reader.readInt64() != nil, let author = parseString(reader), reader.readInt32() != nil, let blocks = parseRichMessageBlockVectorText(reader: reader), let caption = parsePageCaptionFallbackText(reader: reader) else {
            return nil
        }
        return joinRichMessageLines([author, joinRichMessageLines(blocks), caption])
    case 370236054:
        guard let title = parseRichTextChild(reader: reader), consumeApiObjectVector(reader: reader, elementType: Api.PageRelatedArticle.self) else {
            return nil
        }
        return title
    case -1538310410:
        guard let geoSignature = reader.readInt32(), Api.parse(reader, signature: geoSignature) as? Api.GeoPoint != nil, reader.readInt32() != nil, reader.readInt32() != nil, reader.readInt32() != nil else {
            return nil
        }
        return parsePageCaptionFallbackText(reader: reader)
    default:
        telegramApiLog("Unsupported rich message block constructor \(String(UInt32(bitPattern: signature), radix: 16, uppercase: false))")
        return nil
    }
}

private func quoteRichMessageText(_ text: String) -> String {
    if text.isEmpty {
        return ""
    }
    return text.split(separator: "\n", omittingEmptySubsequences: false).map { "> \($0)" }.joined(separator: "\n")
}

private func joinRichMessageLines(_ lines: [String]) -> String {
    return lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: "\n")
}
