//
//  Keychain.swift
//  TradeOgre
//
//  Created by Kyle Roucis on 11/4/21.
//

import Foundation

/// Helper for secure Keychain access
struct Keychain {
    let service: String
    
    private func passwordMap(key: String) -> [String : Any] {
        var keychainMap: [String : Any] = [:]
        keychainMap[(kSecClass as String)] = kSecClassGenericPassword
        keychainMap[(kSecAttrService as String)] = self.service
        let encodedKey: Data? = key.data(using: String.Encoding.utf8)
        keychainMap[(kSecAttrGeneric as String)] = encodedKey
        keychainMap[(kSecAttrAccount as String)] = encodedKey
        return keychainMap
    }
    
    /// Set `passwordString` as the secure item under `key`, or remove the item under `key` if `passwordString` is nil.
    func set(passwordString: String?, key: String) {
        self.set(passwordData: passwordString?.data(using: .utf8), key: key)
    }
    
    /// Set `passwordData` as the secure item under `key`, or remove the item under `key` if `passwordData` is nil.
    func set(passwordData: Data?, key: String) {
        var keychainMap = self.passwordMap(key: key)
        keychainMap[(kSecAttrSynchronizable as String)] = kCFBooleanFalse
        if let data = passwordData {
            keychainMap[(kSecValueData as String)] = data
            let status = SecItemAdd((keychainMap as CFDictionary), nil)
            if status == errSecSuccess {
                // TODO: Maybe return bool?
            }
        }
        else {
            let status: OSStatus = SecItemDelete((keychainMap as CFDictionary))
            if status == errSecSuccess {
                // TODO: Maybe return bool?
            }
        }
    }
    
    /// Get the password string under `key`, or nil if none has been set.
    func passwordString(key: String) -> String? {
        guard let data = self.passwordData(key: key),
            let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }
    
    /// Get the password data under `key`, or nil if none has been set.
    func passwordData(key: String) -> Data? {
        var keychainMap = self.passwordMap(key: key)
        keychainMap[(kSecMatchLimit as String)] = kSecMatchLimitOne
        keychainMap[(kSecReturnData as String)] = kCFBooleanTrue
        var result: AnyObject?
        let status = SecItemCopyMatching((keychainMap as CFDictionary), &result)
        guard status == errSecSuccess,
            let data = result as? Data
        else {
            return nil
        }
        return data
    }
}
