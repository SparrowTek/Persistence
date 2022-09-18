//
//  ObjectManager.swift
//  
//
//  Created by Thomas Rademaker on 9/18/22.
//

import Foundation
import RealmSwift

public typealias Model = Object
public typealias Query = NSPredicate
public typealias Database = Realm

public enum ObjectManagerError: Error {
    case save
    case update
    case delete
}

public struct ObjectManager<T: Model> {
    public init() { }
    
    func write(_ writeBlock: @escaping (Realm) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try Storage.write {
                    writeBlock($0)
                    continuation.resume()
                }
            } catch {
                continuation.resume(throwing: ObjectManagerError.save)
            }
        }
        
        Storage.refresh()
    }
    
    public func loadObject(withID id: String, database: Database = Storage.realm) -> T? {
        database.object(ofType: T.self, forPrimaryKey: id)
    }
    
    public func loadObjects(matching query: Query? = nil, database: Database = Storage.realm) -> [T] {
        guard let query = query else { return Array(database.objects(T.self)) }
        return Array(database.objects(T.self).filter(query))
    }
    
    public func save(_ object: T) async throws {
        try await write {
            $0.create(T.self, value: object, update: .modified)
        }
    }
    
    public func save(_ objects: [T]) async throws {
        try await write { realm in
            for object in objects {
                realm.create(T.self, value: object, update: .modified)
            }
        }
    }
    
    public func saveObjects(_ objects: [T], deleteRestMatching query: Query?) async throws {
        var objectsToDeleteIDs = Set(loadObjects(matching: query).map { $0.value(forKey: "id") as? String ?? "" })
        try await write { realm in
            for object in objects {
                realm.create(T.self, value: object, update: .modified)
                objectsToDeleteIDs.remove(object.value(forKey: "id") as? String ?? "")
            }
            
            for objectID in objectsToDeleteIDs {
                if let object = loadObject(withID: objectID, database: realm) {
                    realm.delete(object)
                }
            }
        }
    }
    
    public func update(_ object: T, block: @escaping (T) -> Void) async throws {
        let ref = ThreadSafeReference(to: object)
        try await write {
            guard let object = $0.resolve(ref) else { return }
            block(object)
        }
    }
    
    public func delete(id: String) async throws {
        try await write {
            guard let object = loadObject(withID: id, database: $0) else { return }
            $0.delete(object)
        }
    }
    
    public func deleteAll(matching query: Query? = nil) async throws {
        try await write {
            let objects = loadObjects(matching: query, database: $0)
            $0.delete(objects)
        }
    }
}

