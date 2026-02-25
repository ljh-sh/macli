import Foundation

struct Cfg {
    private let name: String
    private let configDirectory: URL
    private let configFile: URL
    
    struct Config {
        var data: [String: Any]
        
        init(data: [String: Any] = [:]) {
            self.data = data
        }
        
        var profiles: [[String: Any]] {
            data["profile"] as? [[String: Any]] ?? []
        }
        
        func defaultProfile() -> [String: Any] {
            profiles.first { ($0["name"] as? String) == "X" } ?? profiles.first ?? ["name": "X"]
        }
        
        subscript(key: String) -> Any? {
            data[key]
        }
    }
    
    init(name: String) {
        self.name = name
        self.configDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".x-cmd.root/local/cfg")
        self.configFile = configDirectory.appendingPathComponent("\(name).yml")
    }
    
    func load() -> Config {
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            return Config()
        }
        
        do {
            let yamlString = try String(contentsOf: configFile, encoding: .utf8)
            guard let yaml = SimpleYaml.parse(yamlString) else {
                return Config()
            }
            return Config(data: yaml)
        } catch {
            return Config()
        }
    }
    
    func save(_ config: Config) throws {
        if !FileManager.default.fileExists(atPath: configDirectory.path) {
            try FileManager.default.createDirectory(
                at: configDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        let yamlString = SimpleYaml.dump(config.data)
        try yamlString.write(to: configFile, atomically: true, encoding: .utf8)
    }
    
    func path() -> String {
        return configFile.path
    }
}
