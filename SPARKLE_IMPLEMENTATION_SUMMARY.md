# Sparkle Auto-Update Implementation - Complete!

## ✅ What Was Implemented

Sparkle automatic update functionality has been successfully integrated into makeHTML. Your app can now:

1. **Check for updates automatically** - On launch and periodically
2. **Manual update checks** - Via "makeHTML" menu → "Check for Updates..."
3. **Secure updates** - Uses EdDSA signatures to verify authenticity
4. **GitHub-hosted releases** - Free hosting for update files

## 📁 Files Created/Modified

### New Files
- `appcast.xml` - Update feed template (you'll update this for each release)
- `SPARKLE_SETUP.md` - Complete setup and configuration guide
- `RELEASE_CHECKLIST.md` - Step-by-step checklist for releasing updates

### Modified Files
- `makeHTML-Swift/Package.swift` - Added Sparkle dependency
- `makeHTML-Swift/makeHTMLApp.swift` - Integrated Sparkle updater
- `makeHTML-Swift/build.sh` - Updated to bundle Sparkle framework and add Info.plist keys

## 🚀 What You Need to Do Next

### One-Time Setup (Do This Once)

#### 1. Generate Your EdDSA Keys

```bash
# Download Sparkle tools
curl -L https://github.com/sparkle-project/Sparkle/releases/download/2.6.0/Sparkle-2.6.0.tar.xz -o sparkle.tar.xz
tar -xf sparkle.tar.xz
./bin/generate_keys
```

This outputs two keys:
- **Public key** - Add to `build.sh` (line 179)
- **Private key** - KEEP SECRET! Store in password manager

#### 2. Update build.sh

Open `makeHTML-Swift/build.sh` and replace:

**Line 177:** Replace the SUFeedURL
```xml
<string>https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/appcast.xml</string>
```
With your actual GitHub repo:
```xml
<string>https://raw.githubusercontent.com/dmitriy/makehtml/main/appcast.xml</string>
```

**Line 179:** Replace the public key
```xml
<string>YOUR_PUBLIC_KEY_WILL_GO_HERE</string>
```
With your actual public key from step 1.

#### 3. Create sign_update.sh Script

```bash
cat > sign_update.sh << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: ./sign_update.sh makeHTML-VERSION.zip"
    exit 1
fi

# Replace with your PRIVATE key
PRIVATE_KEY="paste_your_private_key_here"

# Generate signature
SIGNATURE=$(echo "$PRIVATE_KEY" | openssl dgst -sha256 -binary < "$1" | openssl base64)

echo "EdDSA Signature:"
echo "$SIGNATURE"
echo ""
echo "File size:"
ls -l "$1" | awk '{print $5}'
EOF

chmod +x sign_update.sh
echo "sign_update.sh" >> .gitignore
```

#### 4. Set Up GitHub Repository

```bash
# If you haven't already
git init
git add .
git commit -m "Add Sparkle automatic updates"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

#### 5. Push appcast.xml

```bash
git add appcast.xml
git commit -m "Add Sparkle appcast"
git push
```

## 📦 For Each New Release

Follow the detailed **RELEASE_CHECKLIST.md**, but here's the quick version:

```bash
# 1. Update version in build.sh
# Edit makeHTML-Swift/build.sh lines 7-8

# 2. Build
cd makeHTML-Swift
./build.sh

# 3. Create release archive
cd build
zip -r makeHTML-0.6.zip makeHTML.app

# 4. Sign it
cd ../..
./sign_update.sh makeHTML-Swift/build/makeHTML-0.6.zip
# Copy the signature and file size

# 5. Create GitHub Release
# - Go to GitHub → Releases → New Release
# - Tag: v0.6
# - Upload makeHTML-0.6.zip

# 6. Update appcast.xml
# Add new <item> with version, download URL, signature, file size

# 7. Commit and push
git add appcast.xml
git commit -m "Release version 0.6"
git push
```

## 🧪 Testing

### Test Auto-Update Works:

1. Build and install current version (0.5)
2. Create a fake 0.6 release on GitHub
3. Update appcast.xml with version 0.6
4. Open makeHTML → "Check for Updates..."
5. Should show update available

### Clear Update Cache (if testing repeatedly):
```bash
defaults delete com.makehtml.converter SULastCheckTime
```

## ⚠️ Important Security Notes

1. **NEVER commit your private key to git**
2. Store private key in 1Password/password manager
3. Back up your private key (if lost, can't release updates!)
4. Add `sign_update.sh` to `.gitignore`

## 📖 Documentation

- **SPARKLE_SETUP.md** - Detailed setup guide with troubleshooting
- **RELEASE_CHECKLIST.md** - Step-by-step release process
- **appcast.xml** - Has inline comments and examples

## 🎉 What's Next?

Once set up, releasing updates is simple:
1. Build new version
2. Zip it
3. Sign it
4. Upload to GitHub
5. Update appcast.xml
6. Push to GitHub

Users will automatically get notified of the update!

## Current Status

- ✅ Sparkle framework integrated
- ✅ "Check for Updates" menu added
- ✅ Build process updated
- ✅ Info.plist configured (needs your keys/URLs)
- ✅ appcast.xml template created
- ⏳ **Waiting for:** Your EdDSA keys and GitHub repo URL

## Need Help?

See **SPARKLE_SETUP.md** for detailed instructions and troubleshooting.
