import Foundation

struct CfgCtrl {
    private static let cfg = Cfg(name: "macli.X")
    
    static func getAka() -> [String: String] {
        let config = cfg.load()
        let profile = config.defaultProfile()
        return profile["aka"] as? [String: String] ?? [:]
    }
    
    static func getId(_ nameOrID: String) -> String {
        return getAka()[nameOrID] ?? nameOrID
    }
    
    static func setAka(name: String, id: String) throws {
        var config = cfg.load()
        var profiles = config.profiles
        
        var found = false
        for i in 0..<profiles.count {
            if profiles[i]["name"] as? String == "X" {
                var profile = profiles[i]
                var aka = profile["aka"] as? [String: String] ?? [:]
                aka[name] = id
                profile["aka"] = aka
                profiles[i] = profile
                found = true
                break
            }
        }
        
        if !found {
            profiles.insert(["name": "X", "aka": [name: id]], at: 0)
        }
        
        var data = config.data
        data["profile"] = profiles
        try cfg.save(Cfg.Config(data: data))
    }
    
    static func rmAka(name: String) throws -> Bool {
        var config = cfg.load()
        var profiles = config.profiles
        
        var found = false
        for i in 0..<profiles.count {
            if profiles[i]["name"] as? String == "X" {
                var profile = profiles[i]
                var aka = profile["aka"] as? [String: String] ?? [:]
                if aka.removeValue(forKey: name) != nil {
                    profile["aka"] = aka
                    profiles[i] = profile
                    found = true
                }
                break
            }
        }
        
        if found {
            var data = config.data
            data["profile"] = profiles
            try cfg.save(Cfg.Config(data: data))
        }
        
        return found
    }
    
    static func configPath() -> String {
        return cfg.path()
    }
}
