import CoreLocation
import Foundation
import MapKit

enum MapErr: Error, LocalizedError {
    case timeout(String)
    case notFound(String)
    case fail(String)
    
    var errorDescription: String? {
        switch self {
        case .timeout(let m), .notFound(let m), .fail(let m): return m
        }
    }
}

class MapCtrl: NSObject, CLLocationManagerDelegate {
    private let locMgr = CLLocationManager()
    private let geo = CLGeocoder()
    private var locSem = DispatchSemaphore(value: 0)
    private var curLoc: CLLocation?
    private var locErr: Error?

    override init() {
        super.init()
        locMgr.delegate = self
        locMgr.desiredAccuracy = kCLLocationAccuracyBest
    }

    func locationManager(_ mgr: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        curLoc = locs.last
        locSem.signal()
    }

    func locationManager(_ mgr: CLLocationManager, didFailWithError e: Error) {
        locErr = e
        locSem.signal()
    }

    // MARK: Current Location
    func getCurLoc() -> R<[String: Any]> {
        let log = Log.with("Map")
        log.d("Getting current location")
        
        locSem = DispatchSemaphore(value: 0)
        curLoc = nil
        locErr = nil

        locMgr.startUpdatingLocation()
        let r = locSem.wait(timeout: .now() + 10)
        locMgr.stopUpdatingLocation()

        if r == .timedOut {
            log.w("Timeout")
            return .err("Location request timed out")
        }

        if let e = locErr {
            log.e("Failed", more: ["err": e.localizedDescription])
            return .err("Failed: \(e.localizedDescription)")
        }

        guard let loc = curLoc else {
            log.e("No location")
            return .err("Failed to get location")
        }

        log.i("Got location", more: ["lat": loc.coordinate.latitude, "lng": loc.coordinate.longitude])

        var out: [String: Any] = [
            "latitude": loc.coordinate.latitude,
            "longitude": loc.coordinate.longitude,
            "altitude": loc.altitude,
            "horizontalAccuracy": loc.horizontalAccuracy,
            "timestamp": ISO8601DateFormatter().string(from: loc.timestamp)
        ]
        if loc.verticalAccuracy >= 0 { out["verticalAccuracy"] = loc.verticalAccuracy }

        return .ok(["location": out])
    }

    // MARK: Geocoding
    func geocode(_ addr: String) -> R<[[String: Any]]> {
        let log = Log.with("Map")
        log.d("Geocoding", more: ["addr": addr])
        
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = addr

        let sem = DispatchSemaphore(value: 0)
        var resp: MKLocalSearch.Response?
        var err: Error?

        let search = MKLocalSearch(request: req)
        search.start { r, e in
            resp = r
            err = e
            sem.signal()
        }

        let r = sem.wait(timeout: .now() + 30)
        if r == .timedOut {
            log.w("Timeout")
            return .err("Geocoding timed out. Check network.")
        }

        if let e = err {
            log.e("Failed", more: ["err": e.localizedDescription])
            return .err("Geocoding failed: \(e.localizedDescription)")
        }

        guard let response = resp, response.mapItems.first != nil else {
            log.w("No results")
            return .err("No results for: \(addr)")
        }

        let results = response.mapItems.prefix(5).map { item -> [String: Any] in
            [
                "latitude": item.placemark.coordinate.latitude,
                "longitude": item.placemark.coordinate.longitude,
                "name": item.name ?? "",
                "thoroughfare": item.placemark.thoroughfare ?? "",
                "locality": item.placemark.locality ?? "",
                "administrativeArea": item.placemark.administrativeArea ?? "",
                "country": item.placemark.country ?? ""
            ]
        }

        log.i("Geocoded", more: ["count": results.count])
        return .ok(results)
    }

    func revGeocode(lat: Double, lng: Double) -> R<[String: Any]> {
        let log = Log.with("Map")
        log.d("Reverse geocoding", more: ["lat": lat, "lng": lng])
        
        let loc = CLLocation(latitude: lat, longitude: lng)
        let sem = DispatchSemaphore(value: 0)
        var marks: [CLPlacemark]?
        var err: Error?

        geo.reverseGeocodeLocation(loc) { m, e in
            marks = m
            err = e
            sem.signal()
        }

        let r = sem.wait(timeout: .now() + 30)
        if r == .timedOut {
            log.w("Timeout")
            return .err("Reverse geocoding timed out")
        }

        if let e = err {
            log.e("Failed", more: ["err": e.localizedDescription])
            return .err("Reverse geocoding failed: \(e.localizedDescription)")
        }

        guard let mark = marks?.first else {
            log.w("No address")
            return .err("No address found")
        }

        var out: [String: Any] = [
            "latitude": lat,
            "longitude": lng,
            "name": mark.name ?? "",
            "thoroughfare": mark.thoroughfare ?? "",
            "subThoroughfare": mark.subThoroughfare ?? "",
            "locality": mark.locality ?? "",
            "subLocality": mark.subLocality ?? "",
            "administrativeArea": mark.administrativeArea ?? "",
            "country": mark.country ?? "",
            "postalCode": mark.postalCode ?? ""
        ]
        if let areas = mark.areasOfInterest, !areas.isEmpty {
            out["areasOfInterest"] = areas
        }

        log.i("Reverse geocoded")
        return .ok(out)
    }

    // MARK: Search
    func search(_ q: String, nearLat: Double? = nil, nearLng: Double? = nil) -> R<[[String: Any]]> {
        let log = Log.with("Map")
        log.d("Searching", more: ["q": q])
        
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = q

        if let lat = nearLat, let lng = nearLng {
            req.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        }

        let sem = DispatchSemaphore(value: 0)
        var resp: MKLocalSearch.Response?
        var err: Error?

        let search = MKLocalSearch(request: req)
        search.start { r, e in
            resp = r
            err = e
            sem.signal()
        }

        let r = sem.wait(timeout: .now() + 30)
        if r == .timedOut {
            log.w("Timeout")
            return .err("Search timed out")
        }

        if let e = err {
            log.e("Failed", more: ["err": e.localizedDescription])
            return .err("Search failed: \(e.localizedDescription)")
        }

        guard let response = resp else {
            log.w("No results")
            return .err("No results for: \(q)")
        }

        let results = response.mapItems.prefix(10).map { item -> [String: Any] in
            var d: [String: Any] = [
                "name": item.name ?? "",
                "latitude": item.placemark.coordinate.latitude,
                "longitude": item.placemark.coordinate.longitude,
                "thoroughfare": item.placemark.thoroughfare ?? "",
                "locality": item.placemark.locality ?? "",
                "administrativeArea": item.placemark.administrativeArea ?? "",
                "country": item.placemark.country ?? ""
            ]
            if let p = item.phoneNumber { d["phone"] = p }
            if let u = item.url { d["url"] = u.absoluteString }
            return d
        }

        log.i("Search done", more: ["count": results.count])
        return .ok(results)
    }

    // MARK: Directions
    func getRoute(from: String, to: String, mode: MKDirectionsTransportType = .automobile) -> R<[[String: Any]]> {
        let log = Log.with("Map")
        log.d("Getting directions", more: ["from": from, "to": to])
        
        let sem = DispatchSemaphore(value: 0)
        var srcItem: MKMapItem?
        var dstItem: MKMapItem?

        let fromReq = MKLocalSearch.Request()
        fromReq.naturalLanguageQuery = from
        MKLocalSearch(request: fromReq).start { r, _ in
            srcItem = r?.mapItems.first
            sem.signal()
        }
        sem.wait()

        let toReq = MKLocalSearch.Request()
        toReq.naturalLanguageQuery = to
        MKLocalSearch(request: toReq).start { r, _ in
            dstItem = r?.mapItems.first
            sem.signal()
        }
        sem.wait()

        guard let src = srcItem else {
            log.e("Source not found")
            return .err("Could not find: \(from)")
        }
        guard let dst = dstItem else {
            log.e("Dest not found")
            return .err("Could not find: \(to)")
        }

        let req = MKDirections.Request()
        req.source = src
        req.destination = dst
        req.transportType = mode
        req.requestsAlternateRoutes = true

        var dirResp: MKDirections.Response?
        var dirErr: Error?
        let dirSem = DispatchSemaphore(value: 0)

        MKDirections(request: req).calculate { r, e in
            dirResp = r
            dirErr = e
            dirSem.signal()
        }
        dirSem.wait()

        if let e = dirErr {
            log.e("Failed", more: ["err": e.localizedDescription])
            return .err("Directions failed: \(e.localizedDescription)")
        }

        guard let response = dirResp else {
            log.e("No route")
            return .err("No route found")
        }

        let routes = response.routes.map { r -> [String: Any] in
            let steps = r.steps.map { s -> [String: Any] in
                ["instructions": s.instructions, "distance": s.distance]
            }
            return [
                "name": r.name,
                "distance": r.distance,
                "expectedTravelTime": r.expectedTravelTime,
                "steps": steps
            ]
        }

        log.i("Routes found", more: ["count": routes.count])
        return .ok(routes)
    }

    // MARK: Open Maps
    func openInMaps(lat: Double, lng: Double, label: String? = nil) -> R<[String: Any]> {
        let log = Log.with("Map")
        log.d("Opening in Maps", more: ["lat": lat, "lng": lng])
        
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let mark = MKPlacemark(coordinate: coord)
        let item = MKMapItem(placemark: mark)
        item.name = label ?? "Location"
        item.openInMaps(launchOptions: nil)

        log.i("Opened in Maps")
        return .ok([
            "latitude": lat,
            "longitude": lng,
            "name": label ?? "Location"
        ])
    }
}
