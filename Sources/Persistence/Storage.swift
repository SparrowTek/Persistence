//
//  Storage.swift
//  
//
//  Created by Thomas Rademaker on 9/18/22.
//

import Foundation
import RealmSwift
import Realm

public struct StoringConfig {
    public var appGroup: String?
    public var nameSpace: String
    /// Realm schema version, must increment when adding/changing models
    public var realmSchemaVersion: UInt64
    
    public init(appGroup: String?, nameSpace: String, realmSchemaVersion: UInt64) {
        self.appGroup = appGroup
        self.nameSpace = nameSpace
        self.realmSchemaVersion = realmSchemaVersion
    }
}

public protocol Storing {
    static var config: StoringConfig? { get set}
    static func setup(config: StoringConfig)
}

public struct Storage: Storing {
    
    public static var config: StoringConfig?
    
    /// Reference to private queue for performing database write operations
    fileprivate static let writeQueue = DispatchQueue(label: "\(Storage.config?.nameSpace ?? "storage").queue.realm.write")
    
    public static var realmConfiguration: Realm.Configuration {
        guard let config = config else { fatalError("StorageConfig is nil") }
        return Realm.Configuration(
            fileURL: Storage.realmFileURL("\(config.nameSpace).realm"),
            schemaVersion: config.realmSchemaVersion,
            migrationBlock: Storage.migrationBlock,
            deleteRealmIfMigrationNeeded: false,
            shouldCompactOnLaunch: { totalBytes, usedBytes in
                let fiftyMB = 50 * 1024 * 1024
                return (totalBytes > fiftyMB) && (usedBytes < totalBytes / 2)
            }
        )
    }
    
    public static func setup(config: StoringConfig) {
        Storage.config = config
    }
    
    /// Get the path of the realm file, allowing for storing in an application group
    private static func realmFileURL(_ fileName: String) -> URL {
        guard let config = config else { fatalError("StorageConfig is nil") }
        guard let appGroup = config.appGroup, let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return URL(fileURLWithPath: RLMRealmPathForFile(fileName), isDirectory: false)
        }
        return directory.appendingPathComponent(fileName)
    }
    
    /// Default migration block, essentially a no-op. Currently we do not support realm migrations
    private static let migrationBlock: MigrationBlock = { migration, oldSchemaVersion in
        guard let config = config else { fatalError("StorageConfig is nil") }
        guard oldSchemaVersion != config.realmSchemaVersion else { return }
    }
    
    /// Force a realm refresh
    static func refresh() {
        _ = try? Realm().refresh()
    }
    
    /// execute a realm write action
    static func write(block: @escaping (Realm) throws -> Void) throws {
        getRealm(on: writeQueue) { realm in
            if realm.isInWriteTransaction {
                try block(realm)
            } else {
                try realm.write {
                    try block(realm)
                }
            }
        }
    }
    
    /// Asynchronously get a realm on a given queue
    private static func getRealm(on queue: DispatchQueue, block: @escaping (Realm) throws -> ()) {
        guard let config = config else { fatalError("StorageConfig is nil") }
        queue.async {
            autoreleasepool {
                let fileURL = Storage.realmFileURL("\(config.nameSpace).realm")
                let parentURL = fileURL.deletingLastPathComponent()
                try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: parentURL.path)
                
                do {
                    let realm = try Realm(configuration: Storage.realmConfiguration, queue: queue)
                    try block(realm)
                } catch {
                    do {
                        try FileManager.default.removeItem(at: fileURL)
                        let realm = try Realm(configuration: Storage.realmConfiguration, queue: queue)
                        try block(realm)
                    } catch {
                        fatalError("Failed to open Realm: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    public static var realm: Realm {
        guard let config = config else { fatalError("StorageConfig is nil") }
        let fileURL = Storage.realmFileURL("\(config.nameSpace).realm")
        let parentURL = fileURL.deletingLastPathComponent()
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: parentURL.path)
        
        do {
            return try Realm(configuration: Storage.realmConfiguration)
        } catch {
            do {
                try FileManager.default.removeItem(at: fileURL)
                return try Realm(configuration: Storage.realmConfiguration)
            } catch {
                fatalError("Failed to open Realm: \(error.localizedDescription)")
            }
        }
    }
    
    public static func deleteDatabase() {
        try? write {
            $0.deleteAll()
        }
    }
}
