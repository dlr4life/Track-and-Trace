//
//  ExportService.swift
//  T&T Run
//
//  Export track to GPX or GeoJSON for backup or use in other tools.
//

import Foundation
import CoreLocation
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable {
    case gpx = "GPX"
    case geoJSON = "GeoJSON"

    var displayName: String {
        switch self {
        case .gpx: return String(localized: "GPX")
        case .geoJSON: return String(localized: "GeoJSON")
        }
    }
}

struct ExportService {
    /// Generate GPX string from track points.
    static func gpxString(from points: [TrackPoint], trackName: String = "Track") -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="T&amp;T Run">
        <trk><name>\(trackName.xmlEscaped)</name><trkseg>
        """
        let formatter = ISO8601DateFormatter()
        for p in points {
            xml += "<trkpt lat=\"\(p.latitude)\" lon=\"\(p.longitude)\"><time>\(formatter.string(from: p.timestamp))</time><speed>\(p.speed)</speed></trkpt>"
        }
        xml += "</trkseg></trk></gpx>"
        return xml
    }

    /// Generate GeoJSON string from track points.
    static func geoJSONString(from points: [TrackPoint]) -> String {
        let coords = points.map { [ $0.longitude, $0.latitude ] }
        struct GeoJSON: Encodable {
            let type = "Feature"
            let geometry: Geometry
            let properties: Props
            struct Geometry: Encodable {
                let type = "LineString"
                let coordinates: [[Double]]
            }
            struct Props: Encodable {
                let device_id: String
                let count: Int
            }
        }
        let geo = GeoJSON(
            geometry: .init(coordinates: coords),
            properties: .init(device_id: points.first?.deviceID ?? "", count: points.count)
        )
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(geo), let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    /// File extension and UTI for format.
    static func fileExtension(for format: ExportFormat) -> String {
        switch format {
        case .gpx: return "gpx"
        case .geoJSON: return "geojson"
        }
    }

    static func uti(for format: ExportFormat) -> UTType {
        switch format {
        case .gpx: return UTType(filenameExtension: "gpx") ?? .xml
        case .geoJSON: return UTType(filenameExtension: "geojson") ?? .json
        }
    }
}

private extension String {
    var xmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
