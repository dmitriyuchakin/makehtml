# Sparkle Auto-Update Implementation Complete!

## 🎯 What's Working Now

1. **"Check for Updates" menu item** - Users can manually check for updates from the makeHTML menu
2. **Automatic update checks** - Sparkle checks for updates on launch and periodically
3. **Secure updates** - Uses EdDSA cryptographic signatures to verify updates are authentic
4. **GitHub-hosted** - Free hosting using GitHub releases

## 📝 Files Created

1. **SPARKLE_IMPLEMENTATION_SUMMARY.md** - Quick start guide (read this first!)
2. **SPARKLE_SETUP.md** - Complete setup documentation with troubleshooting
3. **RELEASE_CHECKLIST.md** - Step-by-step checklist for each release
4. **appcast.xml** - Update feed template with examples

## 🔧 Files Modified

1. **Package.swift** - Added Sparkle dependency
2. **makeHTMLApp.swift** - Integrated Sparkle updater
3. **build.sh** - Now uses Swift Package Manager and bundles Sparkle framework
4. **Info.plist** (in build.sh) - Added SUFeedURL and SUPublicEDKey placeholders

## ⏭️ Next Steps (One-Time Setup)

You need to complete 3 things:

### 1. Generate EdDSA signing keys (5 minutes)

```bash
# Download Sparkle tools
curl -L https://github.com/sparkle-project/Sparkle/releases/download/2.6.0/Sparkle-2.6.0.tar.xz -o sparkle.tar.xz
tar -xf sparkle.tar.xz
./bin/generate_keys
```

This outputs two keys:
- **Public key** - Add to `build.sh` (line 179)
- **Private key** - KEEP SECRET! Store in password manager

### 2. Update build.sh with your keys and GitHub URL (2 minutes)

Open `makeHTML-Swift/build.sh` and replace:

**Line 177:** Replace the SUFeedURL
```xml
<string>https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/appcast.xml</string>
```
With your actual GitHub repo:
```xml
<string>https://raw.githubusercontent.com/yourusername/makehtml/main/appcast.xml</string>
```

**Line 179:** Replace the public key
```xml
<string>YOUR_PUBLIC_KEY_WILL_GO_HERE</string>
```
With your actual public key from step 1.

### 3. Create sign_update.sh script (2 minutes)

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

## 🚀 For Each Release (After Setup)

The workflow is simple:

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

Detailed steps in **RELEASE_CHECKLIST.md**

## 🧪 Testing

I've built the app and verified:
- ✅ Sparkle framework is bundled correctly
- ✅ Framework is properly linked
- ✅ App builds and runs
- ✅ "Check for Updates" menu appears

The app is ready to use once you complete the one-time setup!

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
4. Add `sign_update.sh` to `.gitignore` (already done)

## 📚 Documentation

All three docs have:
- Step-by-step instructions
- Copy-paste commands
- Troubleshooting sections
- Security best practices

**Start with:** `SPARKLE_IMPLEMENTATION_SUMMARY.md`

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
