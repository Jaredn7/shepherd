import Foundation
import CoreData

public class CoreDataManager {
    public static let shared = CoreDataManager()
    
    public let container: NSPersistentContainer
    
    public var context: NSManagedObjectContext {
        return container.viewContext
    }
    
    private init() {
        let model = CoreDataManager.createModel()
        container = NSPersistentContainer(name: "Shepherd", managedObjectModel: model)
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }
    }
    
    private static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // 1. Publisher
        let publisherEntity = NSEntityDescription()
        publisherEntity.name = "Publisher"
        publisherEntity.managedObjectClassName = "Publisher"
        
        let pubId = NSAttributeDescription()
        pubId.name = "id"
        pubId.attributeType = .UUIDAttributeType
        pubId.isOptional = false
        
        let pubFirstName = NSAttributeDescription()
        pubFirstName.name = "firstName"
        pubFirstName.attributeType = .stringAttributeType
        pubFirstName.isOptional = false
        
        let pubLastName = NSAttributeDescription()
        pubLastName.name = "lastName"
        pubLastName.attributeType = .stringAttributeType
        pubLastName.isOptional = false
        
        let pubPhone = NSAttributeDescription()
        pubPhone.name = "phoneNumber"
        pubPhone.attributeType = .stringAttributeType
        pubPhone.isOptional = true
        
        let pubEmail = NSAttributeDescription()
        pubEmail.name = "email"
        pubEmail.attributeType = .stringAttributeType
        pubEmail.isOptional = true
        
        let pubPrivilege = NSAttributeDescription()
        pubPrivilege.name = "privilegeRaw"
        pubPrivilege.attributeType = .stringAttributeType
        pubPrivilege.isOptional = false
        pubPrivilege.defaultValue = "publisher"
        
        let pubPioneer = NSAttributeDescription()
        pubPioneer.name = "pioneerStatusRaw"
        pubPioneer.attributeType = .stringAttributeType
        pubPioneer.isOptional = false
        pubPioneer.defaultValue = "none"
        
        let pubServiceGroup = NSAttributeDescription()
        pubServiceGroup.name = "serviceGroupId"
        pubServiceGroup.attributeType = .UUIDAttributeType
        pubServiceGroup.isOptional = true
        
        let pubRoles = NSAttributeDescription()
        pubRoles.name = "roles"
        pubRoles.attributeType = .binaryDataAttributeType
        pubRoles.isOptional = false
        
        let pubPublicKey = NSAttributeDescription()
        pubPublicKey.name = "publicKey"
        pubPublicKey.attributeType = .stringAttributeType
        pubPublicKey.isOptional = true
        
        let pubIsActive = NSAttributeDescription()
        pubIsActive.name = "isActive"
        pubIsActive.attributeType = .booleanAttributeType
        pubIsActive.isOptional = false
        pubIsActive.defaultValue = true
        
        let pubCreatedAt = NSAttributeDescription()
        pubCreatedAt.name = "createdAt"
        pubCreatedAt.attributeType = .dateAttributeType
        pubCreatedAt.isOptional = false
        
        let pubUpdatedAt = NSAttributeDescription()
        pubUpdatedAt.name = "updatedAt"
        pubUpdatedAt.attributeType = .dateAttributeType
        pubUpdatedAt.isOptional = false
        
        publisherEntity.properties = [
            pubId, pubFirstName, pubLastName, pubPhone, pubEmail,
            pubPrivilege, pubPioneer, pubServiceGroup, pubRoles,
            pubPublicKey, pubIsActive, pubCreatedAt, pubUpdatedAt
        ]
        
        // 2. ServiceGroup
        let sgEntity = NSEntityDescription()
        sgEntity.name = "ServiceGroup"
        sgEntity.managedObjectClassName = "ServiceGroup"
        
        let sgId = NSAttributeDescription()
        sgId.name = "id"
        sgId.attributeType = .UUIDAttributeType
        sgId.isOptional = false
        
        let sgName = NSAttributeDescription()
        sgName.name = "name"
        sgName.attributeType = .stringAttributeType
        sgName.isOptional = false
        
        let sgOverseer = NSAttributeDescription()
        sgOverseer.name = "overseerId"
        sgOverseer.attributeType = .UUIDAttributeType
        sgOverseer.isOptional = true
        
        let sgAssistants = NSAttributeDescription()
        sgAssistants.name = "assistantIds"
        sgAssistants.attributeType = .binaryDataAttributeType
        sgAssistants.isOptional = false
        
        let sgCreatedAt = NSAttributeDescription()
        sgCreatedAt.name = "createdAt"
        sgCreatedAt.attributeType = .dateAttributeType
        sgCreatedAt.isOptional = false
        
        sgEntity.properties = [sgId, sgName, sgOverseer, sgAssistants, sgCreatedAt]
        
        // 3. PendingLockbox
        let plEntity = NSEntityDescription()
        plEntity.name = "PendingLockbox"
        plEntity.managedObjectClassName = "PendingLockbox"
        
        let plId = NSAttributeDescription()
        plId.name = "id"
        plId.attributeType = .UUIDAttributeType
        plId.isOptional = false
        
        let plType = NSAttributeDescription()
        plType.name = "type"
        plType.attributeType = .stringAttributeType
        plType.isOptional = false
        
        let plSender = NSAttributeDescription()
        plSender.name = "senderPublicKey"
        plSender.attributeType = .stringAttributeType
        plSender.isOptional = false
        
        let plIv = NSAttributeDescription()
        plIv.name = "iv"
        plIv.attributeType = .stringAttributeType
        plIv.isOptional = false
        
        let plCiphertext = NSAttributeDescription()
        plCiphertext.name = "ciphertext"
        plCiphertext.attributeType = .stringAttributeType
        plCiphertext.isOptional = false
        
        let plAuthTag = NSAttributeDescription()
        plAuthTag.name = "authTag"
        plAuthTag.attributeType = .stringAttributeType
        plAuthTag.isOptional = false
        
        let plReceived = NSAttributeDescription()
        plReceived.name = "receivedAt"
        plReceived.attributeType = .dateAttributeType
        plReceived.isOptional = false
        
        let plProcessed = NSAttributeDescription()
        plProcessed.name = "isProcessed"
        plProcessed.attributeType = .booleanAttributeType
        plProcessed.isOptional = false
        plProcessed.defaultValue = false

        let plRemoteId = NSAttributeDescription()
        plRemoteId.name = "remoteId"
        plRemoteId.attributeType = .UUIDAttributeType
        plRemoteId.isOptional = true

        let plSenderDeviceId = NSAttributeDescription()
        plSenderDeviceId.name = "senderDeviceId"
        plSenderDeviceId.attributeType = .UUIDAttributeType
        plSenderDeviceId.isOptional = true

        plEntity.properties = [
            plId, plType, plSender, plIv, plCiphertext, plAuthTag,
            plReceived, plProcessed, plRemoteId, plSenderDeviceId
        ]

        // 4. DeviceDirectoryEntry
        let ddeEntity = NSEntityDescription()
        ddeEntity.name = "DeviceDirectoryEntry"
        ddeEntity.managedObjectClassName = "DeviceDirectoryEntry"

        let ddeId = NSAttributeDescription()
        ddeId.name = "id"
        ddeId.attributeType = .UUIDAttributeType
        ddeId.isOptional = false

        let ddePublisherId = NSAttributeDescription()
        ddePublisherId.name = "publisherId"
        ddePublisherId.attributeType = .UUIDAttributeType
        ddePublisherId.isOptional = true

        let ddeDeviceId = NSAttributeDescription()
        ddeDeviceId.name = "deviceId"
        ddeDeviceId.attributeType = .UUIDAttributeType
        ddeDeviceId.isOptional = false

        let ddePublicKey = NSAttributeDescription()
        ddePublicKey.name = "publicKey"
        ddePublicKey.attributeType = .stringAttributeType
        ddePublicKey.isOptional = false

        let ddeIsElder = NSAttributeDescription()
        ddeIsElder.name = "isElder"
        ddeIsElder.attributeType = .booleanAttributeType
        ddeIsElder.isOptional = false
        ddeIsElder.defaultValue = false

        let ddeUpdatedAt = NSAttributeDescription()
        ddeUpdatedAt.name = "updatedAt"
        ddeUpdatedAt.attributeType = .dateAttributeType
        ddeUpdatedAt.isOptional = false

        ddeEntity.properties = [
            ddeId, ddePublisherId, ddeDeviceId, ddePublicKey, ddeIsElder, ddeUpdatedAt
        ]

        // 5. AccessRequest
        let arEntity = NSEntityDescription()
        arEntity.name = "AccessRequest"
        arEntity.managedObjectClassName = "AccessRequest"

        let arId = NSAttributeDescription()
        arId.name = "id"
        arId.attributeType = .UUIDAttributeType
        arId.isOptional = false

        let arDeviceId = NSAttributeDescription()
        arDeviceId.name = "requesterDeviceId"
        arDeviceId.attributeType = .UUIDAttributeType
        arDeviceId.isOptional = false

        let arPublicKey = NSAttributeDescription()
        arPublicKey.name = "requesterPublicKey"
        arPublicKey.attributeType = .stringAttributeType
        arPublicKey.isOptional = false

        let arRequestedAt = NSAttributeDescription()
        arRequestedAt.name = "requestedAt"
        arRequestedAt.attributeType = .dateAttributeType
        arRequestedAt.isOptional = false

        let arStatus = NSAttributeDescription()
        arStatus.name = "statusRaw"
        arStatus.attributeType = .stringAttributeType
        arStatus.isOptional = false
        arStatus.defaultValue = "pending"

        let arPublisherId = NSAttributeDescription()
        arPublisherId.name = "publisherId"
        arPublisherId.attributeType = .UUIDAttributeType
        arPublisherId.isOptional = true

        arEntity.properties = [arId, arDeviceId, arPublicKey, arRequestedAt, arStatus, arPublisherId]

        model.entities = [publisherEntity, sgEntity, plEntity, ddeEntity, arEntity]
        return model
    }
}
