# Firebase Auth on macOS always sets kSecUseDataProtectionKeychain.
# That keychain requires a signed keychain-access-groups entitlement.
# GitHub release builds are unsigned (no provisioning profile), so
# SecItem* returns errSecMissingEntitlement (-34018) and every sign-in
# surfaces as "Something went wrong".
#
# Signed local builds keep the data-protection keychain (the first call
# succeeds). Unsigned builds retry once against the login keychain.

MARKER = 'ishamela-keychain-fallback'

NEEDLE = <<'SWIFT'.delete_prefix("\n")
  func get(query: [String: Any], result: inout AnyObject?) -> OSStatus {
    return SecItemCopyMatching(query as CFDictionary, &result)
  }

  func add(query: [String: Any]) -> OSStatus {
    return SecItemAdd(query as CFDictionary, nil)
  }

  func update(query: [String: Any], attributes: [String: Any]) -> OSStatus {
    SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
  }

  @discardableResult func delete(query: [String: Any]) -> OSStatus {
    return SecItemDelete(query as CFDictionary)
  }
SWIFT

REPLACEMENT = <<'SWIFT'.delete_prefix("\n")
  // ishamela-keychain-fallback: unsigned macOS builds have no
  // keychain-access-groups entitlement, so the data-protection keychain
  // refuses the write. Retry against the login keychain.
  func get(query: [String: Any], result: inout AnyObject?) -> OSStatus {
    var status = SecItemCopyMatching(query as CFDictionary, &result)
    if shouldReadLoginKeychain(status, query) {
      result = nil
      status = SecItemCopyMatching(loginKeychainQuery(query) as CFDictionary, &result)
    }
    return status
  }

  func add(query: [String: Any]) -> OSStatus {
    let status = SecItemAdd(query as CFDictionary, nil)
    // Add fails closed (-34018). A duplicate is left for the caller to update.
    guard status == errSecMissingEntitlement,
          query[kSecUseDataProtectionKeychain as String] != nil else { return status }
    return SecItemAdd(loginKeychainQuery(query) as CFDictionary, nil)
  }

  func update(query: [String: Any], attributes: [String: Any]) -> OSStatus {
    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    guard shouldReadLoginKeychain(status, query) else { return status }
    return SecItemUpdate(
      loginKeychainQuery(query) as CFDictionary,
      loginKeychainQuery(attributes) as CFDictionary
    )
  }

  @discardableResult func delete(query: [String: Any]) -> OSStatus {
    let status = SecItemDelete(query as CFDictionary)
    guard shouldReadLoginKeychain(status, query) else { return status }
    return SecItemDelete(loginKeychainQuery(query) as CFDictionary)
  }

  // Reads against the data-protection keychain return "not found" (-25300)
  // on an unsigned app even when the session is in the login keychain.
  // Missing entitlement (-34018) is the same refusal on write-shaped calls.
  private func shouldReadLoginKeychain(_ status: OSStatus, _ query: [String: Any]) -> Bool {
    guard query[kSecUseDataProtectionKeychain as String] != nil else { return false }
    return status == errSecMissingEntitlement || status == errSecItemNotFound
  }

  private func loginKeychainQuery(_ query: [String: Any]) -> [String: Any] {
    var copy = query
    copy.removeValue(forKey: kSecUseDataProtectionKeychain as String)
    return copy
  }
SWIFT

def patch_firebase_auth_keychain(installer)
  path = File.join(
    installer.sandbox.root.to_s,
    'FirebaseAuth/FirebaseAuth/Sources/Swift/Storage/AuthKeychainStorageReal.swift'
  )
  patch_firebase_auth_keychain_file(path)
end

def patch_firebase_auth_keychain_file(path)
  unless File.exist?(path)
    raise "FirebaseAuth keychain patch: missing #{path}"
  end

  contents = File.read(path)
  return if contents.include?(MARKER)

  unless contents.include?(NEEDLE)
    raise 'FirebaseAuth keychain patch: AuthKeychainStorageReal.swift no longer matches. ' \
          'Update app/macos/scripts/patch_firebase_auth_keychain.rb.'
  end

  File.chmod(0o644, path)
  File.write(path, contents.sub(NEEDLE, REPLACEMENT))
end
