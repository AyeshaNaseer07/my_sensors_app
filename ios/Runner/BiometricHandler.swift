import LocalAuthentication

class BiometricHandler {
    static let shared = BiometricHandler()
    
    func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("❌ Biometric not available")
            authenticateWithPasscode(reason: reason, completion: completion)
            return
        }
        
        print("🔍 Attempting biometric...")
        
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        ) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Biometric success")
                    completion(true)
                } else {
                    print("❌ Biometric failed")
                    self?.authenticateWithPasscode(reason: reason, completion: completion)
                }
            }
        }
    }
    
    private func authenticateWithPasscode(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            print("❌ Passcode not available")
            completion(false)
            return
        }
        
        print("🔑 Attempting passcode...")
        
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason
        ) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Passcode success")
                    completion(true)
                } else {
                    print("❌ Passcode failed")
                    completion(false)
                }
            }
        }
    }
}
