# Sparkle Automatic Updates Setup Guide

This guide will help you set up automatic updates for makeHTML using Sparkle and GitHub releases.

## One-Time Setup

### Step 1: Generate EdDSA Signing Keys

Sparkle uses EdDSA signatures to ensure updates are authentic and haven't been tampered with.

```bash
# Install Sparkle's generate_keys tool
# Option 1: Download from Sparkle releases
curl -L https://github.com/sparkle-project/Sparkle/releases/download/2.6.0/Sparkle-2.6.0.tar.xz -o sparkle.tar.xz
tar -xf sparkle.tar.xz
./bin/generate_keys

# Option 2: Use Homebrew (if you have it)
brew install sparkle
/opt/homebrew/bin/generate_keys
```

This will output two keys:
- **Public key** - Goes in your app's Info.plist (already has placeholder)
- **Private key** - Keep this SECRET! Store it securely (password manager, keychain, etc.)

**IMPORTANT:** Never commit your private key to git!

### Step 2: Update build.sh with Your Public Key

Open `makeHTML-Swift/build.sh` and replace:
```xml
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_WILL_GO_HERE</string>
```

With your actual public key:
```xml
<key>SUPublicEDKey</key>
<string>abcdef1234567890...your actual public key...</string>
```

### Step 3: Update build.sh with Your GitHub URL

Replace:
```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/appcast.xml</string>
```

With your actual GitHub repository URL:
```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/yourusername/makehtml/main/appcast.xml</string>
```

### Step 4: Create a sign_update Script

Create a file called `sign_update.sh` in the project root:

```bash
#!/bin/bash

# Usage: ./sign_update.sh path/to/makeHTML-VERSION.zip

if [ -z "$1" ]; then
    echo "Usage: ./sign_update.sh path/to/makeHTML-VERSION.zip"
    exit 1
fi

ZIP_FILE="$1"

if [ ! -f "$ZIP_FILE" ]; then
    echo "Error: File not found: $ZIP_FILE"
    exit 1
fi

# Replace this with your actual PRIVATE key (keep secret!)
PRIVATE_KEY="YOUR_PRIVATE_KEY_HERE"

# Generate signature
echo "Generating signature for $ZIP_FILE..."
SIGNATURE=$(echo "$PRIVATE_KEY" | openssl dgst -sha256 -binary < "$ZIP_FILE" | openssl base64)

echo ""
echo "EdDSA Signature:"
echo "$SIGNATURE"
echo ""
echo "File size:"
ls -l "$ZIP_FILE" | awk '{print $5}'
echo ""
echo "Use these values in appcast.xml"
```

Make it executable:
```bash
chmod +x sign_update.sh
```

**IMPORTANT:** Add `sign_update.sh` to `.gitignore` so you don't commit your private key!

```bash
echo "sign_update.sh" >> .gitignore
```

### Step 5: Push appcast.xml to GitHub

Commit and push the `appcast.xml` file to your repository:

```bash
git add appcast.xml
git commit -m "Add Sparkle appcast for automatic updates"
git push origin main
```

## Release Workflow (Every Time You Release)

### Step 1: Update Version Numbers

Update version in `makeHTML-Swift/build.sh`:
```bash
APP_VERSION="0.6"  # Change this
BUILD_NUMBER="1200"  # Change this
```

### Step 2: Build the App

```bash
cd makeHTML-Swift
./build.sh
```

### Step 3: Create Release Archive

```bash
cd build
zip -r makeHTML-0.6.zip makeHTML.app
```

**Important:** Use the `-r` flag to include all contents recursively.

### Step 4: Sign the Update

```bash
cd ..  # Back to project root
./sign_update.sh build/makeHTML-0.6.zip
```

This will output:
- EdDSA signature
- File size in bytes

Save these values - you'll need them for the appcast.

### Step 5: Create GitHub Release

1. Go to your GitHub repository
2. Click "Releases" → "Create a new release"
3. Tag: `v0.6` (match your version number)
4. Title: `Version 0.6`
5. Description: Release notes (what's new, bug fixes, etc.)
6. Upload `makeHTML-0.6.zip`
7. Publish release

### Step 6: Update appcast.xml

Copy the example item in `appcast.xml` and update it:

```xml
<item>
  <title>Version 0.6</title>
  <link>https://github.com/yourusername/makehtml</link>
  <sparkle:version>0.6</sparkle:version>
  <sparkle:shortVersionString>0.6</sparkle:shortVersionString>
  <description><![CDATA[
    <h2>What's New in Version 0.6</h2>
    <ul>
      <li>Your feature here</li>
      <li>Your bug fix here</li>
    </ul>
  ]]></description>
  <pubDate>Mon, 10 Dec 2025 12:00:00 +0000</pubDate>
  <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
  <enclosure
    url="https://github.com/yourusername/makehtml/releases/download/v0.6/makeHTML-0.6.zip"
    sparkle:edSignature="PASTE_SIGNATURE_FROM_STEP_4"
    length="PASTE_FILE_SIZE_FROM_STEP_4"
    type="application/octet-stream"
  />
</item>
```

Important fields:
- `url`: Must match your GitHub release download URL exactly
- `sparkle:edSignature`: The signature from step 4
- `length`: File size in bytes from step 4
- `pubDate`: Use RFC 822 format (you can use `date -R`)

### Step 7: Commit and Push appcast.xml

```bash
git add appcast.xml
git commit -m "Release version 0.6"
git push origin main
```

### Step 8: Test the Update

1. Open the current version of makeHTML
2. Go to makeHTML menu → "Check for Updates..."
3. Should show the new version and offer to install it

## Troubleshooting

### "Update check failed"
- Verify the SUFeedURL in build.sh is correct
- Check that appcast.xml is accessible at that URL
- Make sure GitHub repo is public or token is configured

### "Invalid signature"
- Make sure public key in Info.plist matches your private key
- Verify the signature was generated with the correct private key
- Check that the .zip file wasn't modified after signing

### "No updates found"
- Check that the version in appcast.xml is higher than current version
- Verify sparkle:version format matches (e.g., "0.6" not "v0.6")
- Clear Sparkle cache: `defaults delete com.makehtml.converter SULastCheckTime`

### Users not getting automatic checks
- Sparkle checks on app launch and periodically
- First launch won't check (waits 24 hours by default)
- Users can manually check via menu

## Security Best Practices

1. **Never commit your private key** to version control
2. Store private key in a password manager or macOS Keychain
3. Use different keys for development and production
4. Back up your private key securely (if lost, can't release updates)
5. Always verify signatures before publishing

## Advanced: Automatic Checks

Sparkle automatically checks for updates:
- On app launch (after first 24 hours)
- Every 24 hours while app is running
- Users can disable this in System Settings (future enhancement)

To customize check interval, add to Info.plist:
```xml
<key>SUScheduledCheckInterval</key>
<integer>86400</integer>  <!-- seconds between checks (86400 = 24 hours) -->
```

## Delta Updates (Optional Future Enhancement)

For large apps, Sparkle supports delta updates (only download changed files):
1. Install BinaryDelta tool
2. Generate delta patches between versions
3. Add delta information to appcast

For now, full .zip downloads are fine since makeHTML is small (~2-3MB).
