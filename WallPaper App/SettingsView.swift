//  SettingsView.swift
//  WallPaper App
//
//  Settings interface for managing API tokens and app preferences.
//
//  Created for MVP scaffold.

import SwiftUI

struct SettingsView: View {
    @State private var showingTokenInput = false
    @State private var showingDeleteConfirmation = false
    @State private var currentToken: String?
    @State private var tokenStatus: TokenStatus = .checking
    @State private var errorMessage: String?
    @State private var showFullToken = false
    
    enum TokenStatus: Equatable {
        case checking
        case valid
        case invalid
        case missing
        case error(String)
        
        static func == (lhs: TokenStatus, rhs: TokenStatus) -> Bool {
            switch (lhs, rhs) {
            case (.checking, .checking):
                return true
            case (.valid, .valid):
                return true
            case (.invalid, .invalid):
                return true
            case (.missing, .missing):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // API Token Section
                Section("Steam API Token") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Token Status
                        HStack {
                            Image(systemName: statusIcon)
                                .foregroundColor(statusColor)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(statusTitle)
                                    .font(.headline)
                                Text(statusDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if tokenStatus == .checking {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        
                        // Token Actions
                        HStack(spacing: 12) {
                            Button("Add/Change Token") {
                                showingTokenInput = true
                            }
                            .buttonStyle(.borderedProminent)
                            
                            if TokenManager.shared.hasToken() {
                                Button("Remove Token") {
                                    showingDeleteConfirmation = true
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                                
                                Button("Refresh Token") {
                                    refreshToken()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        // Current Token Display (masked)
                        if let token = currentToken, !token.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Current Token")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text(showFullToken ? token : maskToken(token))
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Button(showFullToken ? "Hide" : "Show") {
                                        showFullToken.toggle()
                                    }
                                    .buttonStyle(.plain)
                                    .font(.caption)
                                }
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                            }
                        }
                        
                        // Error Message
                        if let error = errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Help Section
                Section("Help") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Getting a Steam API Key")
                            .font(.headline)
                        
                        Text("1. Visit the Steam Community Developer page")
                        Text("2. Log in with your Steam account")
                        Text("3. Enter a domain name (can be 'localhost')")
                        Text("4. Copy the generated 32-character key")
                        Text("5. Paste it into the app")
                        
                        Link("Get Steam API Key", destination: URL(string: "https://steamcommunity.com/dev/apikey")!)
                            .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 8)
                }
                
                // Security Section
                Section("Security") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Token Storage")
                            .font(.headline)
                        
                        Text("Your API token is stored locally on your Mac at:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("~/Library/Application Support/WallpaperApp/steam_api_token.txt")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                        
                        Text("The file has restricted permissions and is only accessible by your user account.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                // App Info Section
                Section("App Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Build")
                            Spacer()
                            Text("1")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Platform")
                            Spacer()
                            Text("macOS")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                checkTokenStatus()
            }
            .sheet(isPresented: $showingTokenInput) {
                TokenInputView(isPresented: $showingTokenInput) { newToken in
                    currentToken = newToken
                    checkTokenStatus()
                }
            }
            .alert("Remove API Token", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    removeToken()
                }
            } message: {
                Text("Are you sure you want to remove your Steam API token? You'll need to add it again to browse wallpapers.")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: String {
        switch tokenStatus {
        case .checking:
            return "clock"
        case .valid:
            return "checkmark.circle.fill"
        case .invalid:
            return "xmark.circle.fill"
        case .missing:
            return "exclamationmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusColor: Color {
        switch tokenStatus {
        case .checking:
            return .orange
        case .valid:
            return .green
        case .invalid:
            return .red
        case .missing:
            return .orange
        case .error:
            return .red
        }
    }
    
    private var statusTitle: String {
        switch tokenStatus {
        case .checking:
            return "Checking Token..."
        case .valid:
            return "Token Valid"
        case .invalid:
            return "Token Invalid"
        case .missing:
            return "No Token Found"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    private var statusDescription: String {
        switch tokenStatus {
        case .checking:
            return "Verifying your API token..."
        case .valid:
            return "Your Steam API token is valid and ready to use"
        case .invalid:
            return "The stored token format is invalid"
        case .missing:
            return "No API token found. Add one to browse wallpapers"
        case .error(let message):
            return message
        }
    }
    
    // MARK: - Helper Methods
    
    private func maskToken(_ token: String) -> String {
        guard token.count >= 8 else { return "****" }
        let prefix = String(token.prefix(4))
        let suffix = String(token.suffix(4))
        let middle = String(repeating: "•", count: token.count - 8)
        return "\(prefix)\(middle)\(suffix)"
    }
    
    private func checkTokenStatus() {
        Task {
            await MainActor.run {
                tokenStatus = .checking
                errorMessage = nil
            }
            
            let status = await TokenManager.shared.getTokenStatus()
            
            await MainActor.run {
                switch status {
                case .missing:
                    tokenStatus = .missing
                    currentToken = nil
                case .invalid:
                    tokenStatus = .invalid
                    currentToken = TokenManager.shared.loadToken()
                case .valid:
                    tokenStatus = .valid
                    currentToken = TokenManager.shared.loadToken()
                }
            }
        }
    }
    
    private func refreshToken() {
        checkTokenStatus()
    }
    
    private func removeToken() {
        if TokenManager.shared.deleteToken() {
            currentToken = nil
            tokenStatus = .missing
            errorMessage = nil
        } else {
            errorMessage = "Failed to remove token. Please try again."
        }
    }
}

#Preview {
    SettingsView()
} 