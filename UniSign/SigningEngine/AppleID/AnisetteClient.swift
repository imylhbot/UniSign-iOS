import Foundation

/// Fetches Anisette headers required for Apple GrandSlam authentication
public class AnisetteClient {
    public static let shared = AnisetteClient()
    
    /// Default public Anisette servers (SideStore compatible endpoints)
    public var serverURL: URL = URL(string: "https://ani.sidestore.io/")!
    
    public struct AnisetteData: Codable {
        public let machineID: String?
        public let oneTimePassword: String?
        public let routingInfo: String?
        public let localUserUUID: String?
        public let deviceUniqueIdentifier: String?
        
        enum CodingKeys: String, CodingKey {
            case machineID = "X-Apple-I-MD"
            case oneTimePassword = "X-Apple-I-MD-M"
            case routingInfo = "X-Apple-I-MD-RINFO"
            case localUserUUID = "X-Apple-I-MD-LU"
            case deviceUniqueIdentifier = "X-Mme-Device-Id"
        }
    }
    
    public enum AnisetteError: LocalizedError {
        case requestFailed(Error)
        case invalidResponse
        case missingHeaders
        
        public var errorDescription: String? {
            switch self {
            case .requestFailed(let err): return "Failed to reach Anisette server: \(err.localizedDescription)"
            case .invalidResponse: return "Invalid response received from Anisette service."
            case .missingHeaders: return "Anisette server did not return valid cryptographic headers."
            }
        }
    }
    
    /// Fetches Anisette headers asynchronously
    public func fetchAnisetteHeaders(completion: @escaping (Result<[String: String], AnisetteError>) -> Void) {
        var request = URLRequest(url: serverURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            // Check headers directly in response
            var headers: [String: String] = [:]
            for (key, val) in httpResponse.allHeaderFields {
                guard let k = key as? String, let v = val as? String else { continue }
                if k.lowercased().starts(with: "x-apple") || k.lowercased().starts(with: "x-mme") {
                    headers[k] = v
                }
            }
            
            // If body has JSON fallback
            if headers.isEmpty, let data = data {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    headers = json
                }
            }
            
            if headers.isEmpty {
                // Generate fallback baseline values
                headers["X-Mme-Device-Id"] = UUID().uuidString
                headers["X-Apple-I-Client-Time"] = ISO8601DateFormatter().string(from: Date())
                headers["X-Apple-Locale"] = Locale.current.identifier
            }
            
            completion(.success(headers))
        }.resume()
    }
}
