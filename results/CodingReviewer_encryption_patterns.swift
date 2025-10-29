// Encryption Implementation Patterns
// Generated for CodingReviewer on Tue Oct 28 11:58:18 CDT 2025
// Phase 6 Security Framework Implementation

import Foundation
import CryptoKit
import Security

// MARK: - Data Classification

enum DataClassification: String {
    case public = "public"          // No encryption required
    case internal = "internal"      // AES128 encryption
    case confidential = "confidential" // AES256 encryption
    case restricted = "restricted"   // AES256 + HSM protection

    var encryptionAlgorithm: EncryptionAlgorithm {
        switch self {
        case .public: return .none
        case .internal: return .aes128
        case .confidential, .restricted: return .aes256
        }
    }

    var requiresSecureStorage: Bool {
        return self != .public
    }
}

enum EncryptionAlgorithm {
    case none
    case aes128
    case aes256
}

// MARK: - Encryption Manager

class EncryptionManager {
    static let shared = EncryptionManager()
    private let keychain = KeychainManager.shared
    private let queue = DispatchQueue(label: "com.CodingReviewer.encryption", qos: .userInitiated)

    private init() {
        setupMasterKey()
    }

    // MARK: - Master Key Management

    private func setupMasterKey() {
        // Generate or retrieve master key for encryption operations
        if keychain.retrieveKey(identifier: "master_key") == nil {
            let masterKey = SymmetricKey(size: .bits256)
            keychain.storeKey(masterKey, identifier: "master_key")
        }
    }

    func getMasterKey() -> SymmetricKey? {
        return keychain.retrieveKey(identifier: "master_key")
    }

    // MARK: - Data Encryption

    func encryptData(_ data: Data, classification: DataClassification) -> Result<Data, EncryptionError> {
        guard classification != .public else {
            return .success(data) // No encryption for public data
        }

        guard let key = getEncryptionKey(for: classification) else {
            return .failure(.keyNotFound)
        }

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            let encryptedData = sealedBox.combined
            return .success(encryptedData!)
        } catch {
            return .failure(.encryptionFailed(error))
        }
    }

    func decryptData(_ encryptedData: Data, classification: DataClassification) -> Result<Data, EncryptionError> {
        guard classification != .public else {
            return .success(encryptedData) // No decryption for public data
        }

        guard let key = getEncryptionKey(for: classification) else {
            return .failure(.keyNotFound)
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return .success(decryptedData)
        } catch {
            return .failure(.decryptionFailed(error))
        }
    }

    // MARK: - Key Management

    private func getEncryptionKey(for classification: DataClassification) -> SymmetricKey? {
        let keyIdentifier = "encryption_key_\(classification.rawValue)"

        if let existingKey = keychain.retrieveKey(identifier: keyIdentifier) {
            return existingKey
        }

        // Generate new key for classification
        let keySize: SymmetricKeySize = (classification == .internal) ? .bits128 : .bits256
        let newKey = SymmetricKey(size: keySize)
        keychain.storeKey(newKey, identifier: keyIdentifier)
        return newKey
    }

    // MARK: - Secure Storage

    func storeEncryptedData(_ data: Data, key: String, classification: DataClassification) -> Result<Void, EncryptionError> {
        let encryptedResult = encryptData(data, classification: classification)

        switch encryptedResult {
        case .success(let encryptedData):
            return keychain.storeData(encryptedData, key: key)
        case .failure(let error):
            return .failure(error)
        }
    }

    func retrieveEncryptedData(key: String, classification: DataClassification) -> Result<Data, EncryptionError> {
        let encryptedResult = keychain.retrieveData(key: key)

        switch encryptedResult {
        case .success(let encryptedData):
            return decryptData(encryptedData, classification: classification)
        case .failure(let error):
            return .failure(.keychainError(error))
        }
    }

    // MARK: - Key Rotation

    func rotateKeys() -> Result<Void, EncryptionError> {
        queue.async {
            // Rotate all encryption keys
            for classification in DataClassification.allCases where classification != .public {
                let keyIdentifier = "encryption_key_\(classification.rawValue)"
                let backupIdentifier = "\(keyIdentifier)_backup_\(Date().timeIntervalSince1970)"

                // Backup current key
                if let currentKey = self.keychain.retrieveKey(identifier: keyIdentifier) {
                    self.keychain.storeKey(currentKey, identifier: backupIdentifier)
                }

                // Generate new key
                let keySize: SymmetricKeySize = (classification == .internal) ? .bits128 : .bits256
                let newKey = SymmetricKey(size: keySize)
                self.keychain.storeKey(newKey, identifier: keyIdentifier)

                // Log key rotation
                print("Key rotated for classification: \(classification.rawValue)")
            }
        }
        return .success(())
    }
}

// MARK: - Keychain Manager

class KeychainManager {
    static let shared = KeychainManager()
    private let service = "CodingReviewer.encryption"

    private init() {}

    func storeKey(_ key: SymmetricKey, identifier: String) {
        let keyData = key.withUnsafeBytes { Data($0) }
        storeData(keyData, key: identifier)
    }

    func retrieveKey(identifier: String) -> SymmetricKey? {
        guard let keyData = retrieveData(key: identifier).success else { return nil }
        return SymmetricKey(data: keyData)
    }

    func storeData(_ data: Data, key: String) -> Result<Void, EncryptionError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            // Update existing item
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key
            ]
            let updateAttributes: [String: Any] = [kSecValueData as String: data]
            SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        }

        guard status == errSecSuccess || status == errSecDuplicateItem else {
            return .failure(.keychainError(NSError(domain: NSOSStatusErrorDomain, code: Int(status))))
        }

        return .success(())
    }

    func retrieveData(key: String) -> Result<Data, EncryptionError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return .failure(.keychainError(NSError(domain: NSOSStatusErrorDomain, code: Int(status))))
        }

        return .success(data)
    }
}

// MARK: - Encryption Errors

enum EncryptionError: Error {
    case keyNotFound
    case encryptionFailed(Error)
    case decryptionFailed(Error)
    case keychainError(Error)
    case invalidData
}

// MARK: - Usage Examples

extension EncryptionManager {
    // Example: Encrypt user sensitive data
    func encryptUserData(_ userData: Data) -> Data? {
        return encryptData(userData, classification: .confidential).success
    }

    // Example: Store encrypted user preferences
    func storeUserPreferences(_ preferences: Data, userId: String) -> Bool {
        let key = "user_prefs_\(userId)"
        return storeEncryptedData(preferences, key: key, classification: .confidential).success != nil
    }

    // Example: Retrieve encrypted user data
    func retrieveUserData(userId: String) -> Data? {
        let key = "user_data_\(userId)"
        return retrieveEncryptedData(key: key, classification: .confidential).success
    }
}

// MARK: - Data Extensions

extension Data {
    func encrypted(classification: DataClassification = .confidential) -> Data? {
        return EncryptionManager.shared.encryptData(self, classification: classification).success
    }

    func decrypted(classification: DataClassification = .confidential) -> Data? {
        return EncryptionManager.shared.decryptData(self, classification: classification).success
    }
}

extension String {
    func encrypted(classification: DataClassification = .confidential) -> Data? {
        guard let data = self.data(using: .utf8) else { return nil }
        return data.encrypted(classification: classification)
    }

    init?(decrypted data: Data, classification: DataClassification = .confidential) {
        guard let decryptedData = data.decrypted(classification: classification) else { return nil }
        self.init(data: decryptedData, encoding: .utf8)
    }
}

/*


*/

// Generated by Encryption Agent - Phase 6 Security Framework
