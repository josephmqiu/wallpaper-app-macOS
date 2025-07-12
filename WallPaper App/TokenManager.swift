import Foundation

// MARK: - Token Manager
class TokenManager {
    static let shared = TokenManager()
    
    private let tokenFileName = "steam_api_token.txt"
    private var tokenFileURL: URL? {
        // Store in Application Support directory
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                       in: .userDomainMask).first else {
            return nil
        }
        
        // Create app-specific directory
        let appDirectory = appSupport.appendingPathComponent("WallpaperApp", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDirectory, 
                                               withIntermediateDirectories: true, 
                                               attributes: nil)
        
        return appDirectory.appendingPathComponent(tokenFileName)
    }
    
    private init() {}
    
    // MARK: - Save Token to File
    func saveToken(_ token: String) -> Bool {
        guard let fileURL = tokenFileURL else {
            print("[TokenManager] Failed to get token file URL")
            return false
        }
        
        do {
            // Write token to file
            try token.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // Set file permissions to be readable only by the user
            try FileManager.default.setAttributes([.posixPermissions: 0o600], 
                                                ofItemAtPath: fileURL.path)
            
            print("[TokenManager] Token saved successfully to: \(fileURL.path)")
            return true
        } catch {
            print("[TokenManager] Failed to save token: \(error)")
            return false
        }
    }
    
    // MARK: - Load Token from File
    func loadToken() -> String? {
        guard let fileURL = tokenFileURL else {
            print("[TokenManager] Failed to get token file URL")
            return nil
        }
        
        do {
            // Check if file exists
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("[TokenManager] Token file does not exist")
                return nil
            }
            
            // Read token from file
            let token = try String(contentsOf: fileURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate token is not empty
            guard !token.isEmpty else {
                print("[TokenManager] Token file is empty")
                return nil
            }
            
            print("[TokenManager] Token loaded successfully")
            return token
        } catch {
            print("[TokenManager] Failed to load token: \(error)")
            return nil
        }
    }
    
    // MARK: - Delete Token from File
    func deleteToken() -> Bool {
        guard let fileURL = tokenFileURL else {
            print("[TokenManager] Failed to get token file URL")
            return false
        }
        
        do {
            // Check if file exists before trying to delete
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
                print("[TokenManager] Token deleted successfully")
            }
            return true
        } catch {
            print("[TokenManager] Failed to delete token: \(error)")
            return false
        }
    }
    
    // MARK: - Check if Token Exists
    func hasToken() -> Bool {
        return loadToken() != nil
    }
    
    // MARK: - Validate Token Format
    func isValidTokenFormat(_ token: String) -> Bool {
        // Steam API tokens are typically 32 character hexadecimal strings
        let hexPattern = "^[A-Fa-f0-9]{32}$"
        let regex = try? NSRegularExpression(pattern: hexPattern)
        let range = NSRange(location: 0, length: token.utf16.count)
        return regex?.firstMatch(in: token, options: [], range: range) != nil
    }
    
    // MARK: - Validate Token with Steam API
    func validateTokenWithSteam(_ token: String) async -> Bool {
        // Make a test API call to validate the token
        var components = URLComponents(string: "https://api.steampowered.com/IPublishedFileService/QueryFiles/v1/")!
        components.queryItems = [
            URLQueryItem(name: "key", value: token),
            URLQueryItem(name: "creator_appid", value: "431960"), // Wallpaper Engine app ID
            URLQueryItem(name: "appid", value: "431960"),
            URLQueryItem(name: "query_type", value: "9"),
            URLQueryItem(name: "cursor", value: "*"),
            URLQueryItem(name: "numperpage", value: "1"), // Just get 1 result to test
            URLQueryItem(name: "return_metadata", value: "false"),
            URLQueryItem(name: "return_preview_url", value: "false"),
            URLQueryItem(name: "return_file_url", value: "false")
        ]
        
        guard let url = components.url else {
            return false
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                // Check if we got a successful response
                if httpResponse.statusCode == 200 {
                    // Try to parse the response to see if it's valid
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let _ = json["response"] as? [String: Any] {
                        // If we get a response object, the token is likely valid
                        return true
                    }
                }
            }
            
            return false
        } catch {
            print("[TokenManager] Token validation failed: \(error)")
            return false
        }
    }
    
    // MARK: - Get Token Status
    func getTokenStatus() async -> TokenStatus {
        guard let token = loadToken() else {
            return .missing
        }
        
        if !isValidTokenFormat(token) {
            return .invalid
        }
        
        // Validate with Steam API
        let isValid = await validateTokenWithSteam(token)
        return isValid ? .valid : .invalid
    }
    
    // MARK: - Token Status Enum
    enum TokenStatus {
        case missing
        case invalid
        case valid
    }
}

// MARK: - Token Input View
import SwiftUI

struct TokenInputView: View {
    @Binding var isPresented: Bool
    @State private var token: String = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    let onTokenSaved: (String) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                Text("Steam API Token Required")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Please enter your Steam Web API key to browse wallpapers")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Your token will be stored locally on your Mac")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Token Input
            VStack(alignment: .leading, spacing: 8) {
                Text("API Token")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SecureField("Enter your Steam API token", text: $token)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        saveToken()
                    }
                
                if let error = errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Help Link
            Link(destination: URL(string: "https://steamcommunity.com/dev/apikey")!) {
                Label("Get your Steam API key", systemImage: "link")
                    .font(.caption)
            }
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                
                Button("Save") {
                    saveToken()
                }
                .buttonStyle(.borderedProminent)
                .disabled(token.isEmpty || isLoading)
            }
        }
        .padding(32)
        .frame(width: 450)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func saveToken() {
        errorMessage = nil
        
        // Validate token format
        guard TokenManager.shared.isValidTokenFormat(token) else {
            errorMessage = "Invalid token format. Please enter a valid 32-character API key."
            return
        }
        
        // Save token
        if TokenManager.shared.saveToken(token) {
            onTokenSaved(token)
            isPresented = false
        } else {
            errorMessage = "Failed to save token. Please try again."
        }
    }
}