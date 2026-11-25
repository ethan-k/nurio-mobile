enum LocalePath {
    static func stripLocalePrefix(_ path: String) -> String {
        let scalars = path.unicodeScalars
        let prefix = String(scalars.prefix(3))
        guard prefix.utf8.count == 3 else { return path }
        let locale = prefix.lowercased()
        guard locale == "/en" || locale == "/ko" else { return path }

        let remainder = scalars.dropFirst(3)
        switch remainder.first {
        case "/": return "/" + String(remainder.drop(while: { $0 == "/" }))
        case nil, "?", "#": return "/" + String(remainder)
        default: return path
        }
    }
}
