# API Token Storage Information

## Token Storage Location

Your Steam API token is stored locally on your Mac at:
```
~/Library/Application Support/WallpaperApp/steam_api_token.txt
```

## Security Measures

- The token file has restricted permissions (0o600) - only readable by your user account
- The file is stored in your user Library folder which has restricted access
- The token is never transmitted over the network except to Steam's API

## Managing Your Token

### To view your stored token:
1. Open Finder
2. Press `Cmd + Shift + G` to open "Go to Folder"
3. Enter: `~/Library/Application Support/WallpaperApp/`
4. Open `steam_api_token.txt` with TextEdit

### To change your token:
1. In the app, go to the menu bar
2. Select `WallpaperApp > Change API Token...`
3. Or use the keyboard shortcut `Cmd + Shift + ,`

### To delete your token:
Simply delete the file at the location above, or use the "Change API Token" option and save an empty token.

## Getting a Steam API Key

1. Visit https://steamcommunity.com/dev/apikey
2. Log in with your Steam account
3. Enter a domain name (can be anything like "localhost")
4. Copy the generated 32-character key
5. Paste it into the app when prompted

## Troubleshooting

If the app can't save or load your token:
1. Ensure you have write permissions to `~/Library/Application Support/`
2. Check that the WallpaperApp directory exists
3. Try deleting the token file and re-entering it in the app

## Note on Security

While file-based storage is less secure than macOS Keychain, we've implemented several measures to protect your token:
- Restricted file permissions
- Storage in a protected system directory
- No transmission of the token except to Steam's official API

For maximum security, ensure your Mac user account has a strong password and FileVault encryption is enabled.