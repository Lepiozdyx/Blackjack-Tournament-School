import Foundation

struct StateRepository {
    let directory: URL
    var url: URL { directory.appendingPathComponent("progress-v1.json") }
    init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("BJapp", isDirectory: true)
    }
    func load() throws -> SavedState {
        guard FileManager.default.fileExists(atPath: url.path) else { return SavedState() }
        let state = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: url))
        guard state.version == 1 else { throw CocoaError(.coderReadCorrupt) }
        return state
    }
    func save(_ state: SavedState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: .atomic)
    }
}
