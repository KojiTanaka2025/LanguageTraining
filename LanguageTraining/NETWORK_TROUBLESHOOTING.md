# Network Troubleshooting

Use this guide when LanguageTraining cannot connect to the OpenAI API or shows a network-related error.

## Check Xcode Project Settings

### App Sandbox And Network Access

Open the project in Xcode and check the following:

1. Select the `LanguageTraining` project in the project navigator.
2. Select the `LanguageTraining` target.
3. Open Signing & Capabilities.
4. Confirm that App Sandbox is enabled.
5. Confirm that Outgoing Connections (Client) is enabled.

### Entitlements File

Confirm that `LanguageTraining.entitlements` exists and includes:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

### Build Settings

In Build Settings, confirm:

- Code Signing Entitlements: `LanguageTraining/LanguageTraining.entitlements`
- Enable App Sandbox: `YES`

## Connection Test

After rebuilding and launching the app:

1. Open the Explain tab.
2. Paste a short word such as `hello`.
3. Click Explain.
4. Review the result.

Expected outcomes:

- An explanation means networking is working. Check the API key if authentication fails.
- A DNS, timeout, or sandbox error means the network configuration still needs attention.

## Common Problems

### DNS Cannot Resolve The Host

Possible causes:

- No internet connection
- DNS server issue
- VPN routing problem

Fixes:

1. Open a browser and confirm that normal websites load.
2. Temporarily disable VPN and test again.
3. Allow access to the OpenAI API in your VPN or network policy.
4. Try a different DNS server such as Cloudflare DNS or Google DNS.
5. Flush the DNS cache:

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Connection Timeout

Possible causes:

- Firewall blocking the app
- Security software blocking outgoing HTTPS connections
- Network proxy issue

Fixes:

1. Check macOS firewall settings.
2. Check third-party antivirus or firewall tools.
3. Test from a different network.
4. Confirm that `https://api.openai.com` is reachable.

### App Transport Security Or Invalid URL

LanguageTraining requires HTTPS API endpoints.

Use:

```text
https://api.openai.com
```

Do not use:

```text
http://api.openai.com
```

### App Sandbox Blocks Network Access

Fixes:

1. Open Signing & Capabilities.
2. Confirm App Sandbox is enabled.
3. Confirm Outgoing Connections (Client) is checked.
4. Clean the build folder with `Shift + Command + K`.
5. Build again with `Command + B`.

If needed, remove DerivedData:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

## Manual Entitlements Setup

If the entitlements file is missing:

1. Open the project in Xcode.
2. Choose File > New > File.
3. Select Property List.
4. Name the file `LanguageTraining.entitlements`.
5. Add the required sandbox and network keys.
6. Set Build Settings > Code Signing Entitlements to `LanguageTraining/LanguageTraining.entitlements`.

Recommended content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <false/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

## Checklist

- [ ] Internet access works.
- [ ] The Base URL is `https://api.openai.com` or another trusted HTTPS endpoint.
- [ ] The OpenAI API key is entered correctly.
- [ ] App Sandbox is enabled.
- [ ] Outgoing Connections (Client) is enabled.
- [ ] `LanguageTraining.entitlements` is configured in Build Settings.
- [ ] The app has been rebuilt after changing signing settings.
- [ ] Firewall or security tools are not blocking the app.

## Test With Curl

Run this command in Terminal to confirm that the OpenAI API is reachable:

```bash
curl -X POST https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"test"}]}'
```

Replace `YOUR_API_KEY` with a valid API key.

Expected results:

- A JSON response means the API is reachable.
- A 401 response usually means the key is invalid or expired.
- A "Could not resolve host" error points to DNS or network issues.
- A successful curl response but failing app request usually points to sandbox, signing, or app configuration.

## Reporting A Network Issue

Include the following details when reporting a network problem:

- macOS version
- Xcode version
- Whether VPN or proxy is enabled
- Full error message
- Base URL setting
- Resolved endpoint shown in Settings
- Whether curl succeeds

