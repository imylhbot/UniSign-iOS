import Foundation

class AppLibraryStore {
    static let shared = AppLibraryStore()

    private let storeFileName = "signed_apps_registry.json"
    private var records: [SignedAppRecord] = []
    private let queue = DispatchQueue(label: "com.soulsign.applibrarystore", attributes: .concurrent)

    private init() {
        loadRecords()
    }

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(storeFileName)
    }

    private func loadRecords() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SignedAppRecord].self, from: data) {
            records = decoded
        }
    }

    private func saveRecords() {
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: fileURL)
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("SoulSignAppLibraryUpdatedNotification"), object: nil)
        }
    }

    func getAllRecords() -> [SignedAppRecord] {
        return queue.sync { records }
    }

    func addOrUpdateRecord(_ record: SignedAppRecord) {
        queue.async(flags: .barrier) {
            if let index = self.records.firstIndex(where: { $0.bundleID == record.bundleID }) {
                self.records[index] = record
            } else {
                self.records.insert(record, at: 0)
            }
            self.saveRecords()
        }
    }

    func deleteRecord(bundleID: String) {
        queue.async(flags: .barrier) {
            self.records.removeAll { $0.bundleID == bundleID }
            self.saveRecords()
        }
    }

    /// Returns count of signed apps associated with a specific Apple ID email
    func activeAppsCount(for email: String) -> Int {
        return queue.sync {
            self.records.filter { $0.appleIDEmail.lowercased() == email.lowercased() }.count
        }
    }

    /// Returns all records for a specific Apple ID email
    func records(for email: String) -> [SignedAppRecord] {
        return queue.sync {
            self.records.filter { $0.appleIDEmail.lowercased() == email.lowercased() }
        }
    }
}
