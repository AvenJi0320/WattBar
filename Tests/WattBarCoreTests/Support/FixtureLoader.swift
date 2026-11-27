import Foundation

enum FixtureLoader {
    static func load(_ name: String) throws -> [[String: Any]] {
        guard let url = Bundle.module.url(
            forResource: name, withExtension: "plist", subdirectory: "Fixtures"
        ) else {
            throw FixtureError.missing(name)
        }
        let data = try Data(contentsOf: url)
        let object = try PropertyListSerialization.propertyList(from: data, format: nil)
        return (object as? [[String: Any]]) ?? []
    }

    static func flatten(_ roots: [[String: Any]]) -> [[String: Any]] {
        roots.flatMap { node -> [[String: Any]] in
            let children = (node["IORegistryEntryChildren"] as? [[String: Any]]) ?? []
            return [node] + flatten(children)
        }
    }
}

enum FixtureError: Error {
    case missing(String)
}
