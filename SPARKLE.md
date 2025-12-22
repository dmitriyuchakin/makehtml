# Sparkle Auto-Updates Guide

Complete guide for setting up and maintaining automatic updates in makeHTML using Sparkle + GitHub.

---

## 📋 Table of Contents
- [What's Already Done](#whats-already-done)
- [One-Time Setup](#one-time-setup)
- [Release Workflow](#release-workflow)
- [Testing Updates](#testing-updates)
- [Troubleshooting](#troubleshooting)

---

## What's Already Done

✅ Sparkle framework integrated
✅ "Check for Updates" menu added
✅ Build script configured
✅ Appcast template created

**What you need to do:** Complete the one-time setup below.

---

## One-Time Setup

### Step 1: Generate EdDSA Keys (5 min)

```bash
# Download Sparkle's key generator
curl -L https://github.com/sparkle-project/Sparkle/releases/download/2.6.0/Sparkle-2.6.0.tar.xz -o sparkle.tar.xz
tar -xf sparkle.tar.xz
./bin/generate_keys
```

You'll get two keys:
- **Public key** → Goes in `build.sh`
- **Private key** → Store in password manager (NEVER commit this!)

### Step 2: Update build.sh (2 min)

Open `makeHTML-Swift/build.sh` and update lines 177 & 179:

```xml
<!-- Line 177: Your GitHub repo URL -->
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/yourusername/makehtml/main/appcast.xml</string>

<!-- Line 179: Your public key from Step 1 -->
<key>SUPublicEDKey</key>
<string>paste_your_public_key_here</string>
```

### Step 3: Create Signing Script (2 min)

Create `sign_update.sh` in project root:

```bash
cat > sign_update.sh << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: ./sign_update.sh makeHTML-VERSION.zip"
    exit 1
fi

# IMPORTANT: Replace with your PRIVATE key from Step 1
PRIVATE_KEY="paste_your_private_key_here"

# Generate signature
SIGNATURE=$(echo "$PRIVATE_KEY" | openssl dgst -sha256 -binary < "$1" | openssl base64)

echo ""
echo "EdDSA Signature:"
echo "$SIGNATURE"
echo ""
echo "File size (bytes):"
ls -l "$1" | awk '{print $5}'
echo ""
EOF

chmod +x sign_update.sh
```

**Important:** `sign_update.sh` is already in `.gitignore` - never commit it!

### Step 4: Enable Auto-Start (Optional)

Once setup is complete, you can enable automatic update checks on launch:

Open `makeHTML-Swift/makeHTMLApp.swift` line 80 and change:
```swift
startingUpdater: false  // Change to: true
```

### Step 5: Push appcast.xml to GitHub

```bash
git add appcast.xml
git commit -m "Add Sparkle appcast for automatic updates"
git push origin main
```

---

## Release Workflow

Follow these steps every time you release a new version:

### 1. Update Version Numbers

Edit `makeHTML-Swift/build.sh`:
```bash
APP_VERSION="0.6"    # Line 7 - Increment this
BUILD_NUMBER="1200"  # Line 8 - Increment this
```

Optional: Update About panel in `makeHTMLApp.swift` line 32 if needed.

### 2. Build the App

```bash
cd makeHTML-Swift
./build.sh
```

### 3. Create Release Archive

```bash
cd build
zip -r makeHTML-0.6.zip makeHTML.app
cd ../..
```

### 4. Sign the Update

```bash
./sign_update.sh makeHTML-Swift/build/makeHTML-0.6.zip
```

**Copy the output:**
- EdDSA Signature
- File size in bytes

### 5. Create GitHub Release

1. Go to: `https://github.com/yourusername/yourrepo/releases`
2. Click **"Create a new release"**
3. Tag: `v0.6` (match your version)
4. Title: `Version 0.6`
5. Description: Write release notes
6. Upload: `makeHTML-0.6.zip`
7. Click **Publish release**

### 6. Update appcast.xml

Add a new `<item>` block at the top (after line 33):

```xml
<item>
  <title>Version 0.6</title>
  <link>https://github.com/yourusername/yourrepo</link>
  <sparkle:version>0.6</sparkle:version>
  <sparkle:shortVersionString>0.6</sparkle:shortVersionString>
  <description><![CDATA[
    <h2>What's New in Version 0.6</h2>
    <ul>
      <li>Feature 1</li>
      <li>Bug fix 2</li>
      <li>Improvement 3</li>
    </ul>
  ]]></description>
  <pubDate>Sat, 21 Dec 2025 12:00:00 +0000</pubDate>
  <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
  <enclosure
    url="https://github.com/yourusername/yourrepo/releases/download/v0.6/makeHTML-0.6.zip"
    sparkle:edSignature="PASTE_SIGNATURE_FROM_STEP_4"
    length="FILE_SIZE_FROM_STEP_4"
    type="application/octet-stream"
  />
</item>
```

**Important fields:**
- `url`: Must match GitHub release download URL exactly
- `sparkle:edSignature`: From step 4
- `length`: From step 4 (in bytes)
- `pubDate`: Use `date -R` for correct format

### 7. Commit and Push

```bash
git add appcast.xml makeHTML-Swift/build.sh
git commit -m "Release version 0.6"
git push origin main
```

### 8. Test

Open your current version → makeHTML menu → "Check for Updates..."

---

## Testing Updates

### Test Before Publishing

1. Build version 0.6
2. Create a draft GitHub release with the .zip
3. Update appcast.xml with draft release URL
4. Open version 0.5 and check for updates
5. Verify it detects version 0.6
6. Test the update installs correctly
7. Publish the release

### Clear Update Cache

If testing repeatedly:
```bash
defaults delete com.makehtml.converter SULastCheckTime
```

### Verify appcast.xml is Accessible

```bash
curl https://raw.githubusercontent.com/yourusername/yourrepo/main/appcast.xml
```

---

## Troubleshooting

### "Update check failed"
- Verify SUFeedURL in `build.sh` is correct
- Check appcast.xml is accessible (use curl command above)
- Ensure GitHub repo is public

### "Invalid signature"
- Public key in `build.sh` must match your private key
- Verify signature was generated with correct private key
- Don't modify .zip after signing

### "No updates found"
- Version in appcast.xml must be higher than current
- Version format must match exactly (e.g., "0.6" not "v0.6")
- Check `sparkle:version` field

### App shows error on launch
- Set `startingUpdater: false` in makeHTMLApp.swift until setup is complete
- Verify SUFeedURL and SUPublicEDKey are valid (not placeholders)

### Users not getting automatic checks
- Sparkle checks on launch and every 24 hours
- First launch won't check (waits 24 hours by default)
- Users can manually check via menu

---

## Security Best Practices

🔐 **Never commit your private key to git**
🔐 Store private key in 1Password or password manager
🔐 Back up your private key (if lost, can't release updates)
🔐 `sign_update.sh` is in `.gitignore` - keep it there

---

## Quick Reference

### Useful Commands

```bash
# Get date in RFC 822 format
date -R

# Check appcast accessibility
curl https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/appcast.xml

# Clear Sparkle cache
defaults delete com.makehtml.converter SULastCheckTime

# Check what rpath binary has
otool -l build/makeHTML.app/Contents/MacOS/makeHTML | grep RPATH -A 2
```

### File Locations

- Appcast: `appcast.xml` (in repo root)
- Config: `makeHTML-Swift/build.sh` (lines 177, 179)
- Signing script: `sign_update.sh` (in repo root, gitignored)
- Menu integration: `makeHTML-Swift/makeHTMLApp.swift`

---

## What Happens When Users Get Updates

1. Sparkle checks appcast.xml for new versions
2. If found, shows update dialog with release notes
3. User clicks "Install Update"
4. Downloads .zip file from GitHub
5. Verifies EdDSA signature
6. Extracts and replaces app
7. Relaunches with new version

All automatic and secure! 🎉
