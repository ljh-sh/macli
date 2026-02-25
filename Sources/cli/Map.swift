import Foundation
import MapKit

enum MapCmd: Cmd {
    static let meta = CmdMeta(
        name: "map",
        alias: ["m"],
        desc: "Map and location services",
        subcmds: [
            "search": MapSearch.self,
            "geocode": MapGeocode.self,
            "reverse": MapReverse.self,
            "directions": MapDirections.self,
            "open": MapOpen.self,
        ]
    )
    
    static func getTLDR() -> [TldrItem]? {
        [
            TldrItem(desc: "Search for places", cmd: "macli map search 'coffee shop'"),
            TldrItem(desc: "Get coordinates from address", cmd: "macli map geocode '1600 Amphitheatre Parkway'"),
            TldrItem(desc: "Get address from coordinates", cmd: "macli map reverse --lat 37.422 --lng -122.084"),
            TldrItem(desc: "Get directions", cmd: "macli map directions --from 'San Francisco' --to 'San Jose'"),
            TldrItem(desc: "Open location in Maps", cmd: "macli map open --lat 37.422 --lng -122.084 --name 'Google'"),
        ]
    }
}

enum MapSearch: Cmd {
    static let meta = CmdMeta(
        name: "search",
        desc: "Search for places",
        opts: [
            OptMeta(name: "--lat", type: Double.self, desc: "Latitude to search near"),
            OptMeta(name: "--lng", type: Double.self, desc: "Longitude to search near"),
        ],
        args: [ArgMeta(name: "query", desc: "Search query")],
        run: { p in
            let query: String = requireArg(p, 0, "Query")
            let lat: Double? = p.opt("--lat")
            let lng: Double? = p.opt("--lng")
            let r = MapCtrl().search(query, nearLat: lat, nearLng: lng)
            print(x.json.stringify(r) { ["query": query, "results": $0, "count": $0.count] })
        }
    )
}

enum MapGeocode: Cmd {
    static let meta = CmdMeta(
        name: "geocode",
        desc: "Convert address to coordinates",
        args: [ArgMeta(name: "address")],
        run: { p in
            let addr: String = requireArg(p, 0, "Address")
            let r = MapCtrl().geocode(addr)
            print(x.json.stringify(r) { ["query": addr, "results": $0, "count": $0.count] })
        }
    )
}

enum MapReverse: Cmd {
    static let meta = CmdMeta(
        name: "reverse",
        desc: "Convert coordinates to address",
        opts: [
            OptMeta(name: "--lat", type: Double.self, desc: "Latitude", required: true),
            OptMeta(name: "--lng", type: Double.self, desc: "Longitude", required: true),
        ],
        run: { p in
            let lat: Double = requireOpt(p, "--lat")
            let lng: Double = requireOpt(p, "--lng")
            let r = MapCtrl().revGeocode(lat: lat, lng: lng)
            print(x.json.stringify(r) { ["address": $0] })
        }
    )
}

enum MapDirections: Cmd {
    static let meta = CmdMeta(
        name: "directions",
        desc: "Get directions",
        opts: [
            OptMeta(name: "--from", desc: "From address", required: true),
            OptMeta(name: "--to", desc: "To address", required: true),
            OptMeta(name: "--walk", type: Bool.self, desc: "Walking mode"),
        ],
        run: { p in
            let from: String = requireOpt(p, "--from")
            let to: String = requireOpt(p, "--to")
            let walk: Bool = p.opt("--walk") ?? false
            let mode = walk ? MKDirectionsTransportType.walking : MKDirectionsTransportType.automobile
            let r = MapCtrl().getRoute(from: from, to: to, mode: mode)
            print(x.json.stringify(r) { ["from": from, "to": to, "routes": $0] })
        }
    )
}

enum MapOpen: Cmd {
    static let meta = CmdMeta(
        name: "open",
        desc: "Open in Maps app",
        opts: [
            OptMeta(name: "--lat", type: Double.self, desc: "Latitude", required: true),
            OptMeta(name: "--lng", type: Double.self, desc: "Longitude", required: true),
            OptMeta(name: "--name", desc: "Location name"),
        ],
        run: { p in
            let lat: Double = requireOpt(p, "--lat")
            let lng: Double = requireOpt(p, "--lng")
            let name: String? = p.opt("--name")
            let r = MapCtrl().openInMaps(lat: lat, lng: lng, label: name)
            print(x.json.stringify(r) { ["message": "Opened", "location": $0] })
        }
    )
}
