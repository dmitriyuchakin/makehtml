# Release Process

This document outlines the steps for creating and publishing a new release of makeHTML.

## Prerequisites

- All changes committed and pushed to `origin/main` (private repo)
- App tested and working
- Version number decided (e.g., `1.0.1`)

## Release Steps

### 1. Update Version Number

Update the version in `makeHTML-Swift/build.sh`:

```bash
APP_VERSION="0.7.1"      # Line 9 - Marketing version (X.Y)
BUILD_NUMBER="260102"  # Line 10 - Build number (YYMMDD format)
```

**Note**: The About dialog will automatically display these values from the built app's Info.plist.

### 2. Build the Release

```bash
cd makeHTML-Swift
./build.sh
```

This creates `makeHTML-Swift/build/makeHTML.app`

### 3. Create Release Archive

```bash
cd makeHTML-Swift/build
zip -r makeHTML.zip makeHTML.app
cd ../..
```

**Note**: The app is already code-signed during the build process (you'll see "✓ App signed" in build output).

### 4. Sign the Update Package

Generate Sparkle update signature:

```bash
./sign_update.sh makeHTML-Swift/build/makeHTML.zip
```

This outputs two important values:
- **EdDSA Signature**: Add to `appcast.xml` as `sparkle:edSignature="..."`
- **File size (bytes)**: Add to `appcast.xml` as `length="..."`

### 5. Update appcast.xml

Add a new `<item>` entry at the top of the `<channel>` section:

```xml
<item>
    <title>Version 1.0.1</title>
    <sparkle:releaseNotesLink>
        https://github.com/dmitriyuchakin/makehtml/releases/tag/v1.0.1
    </sparkle:releaseNotesLink>
    <pubDate>Thu, 02 Jan 2026 12:00:00 +0000</pubDate>
    <enclosure
        url="https://github.com/dmitriyuchakin/makehtml/releases/download/v1.0.1/makeHTML.zip"
        sparkle:version="1.0.1"
        sparkle:shortVersionString="1.0.1"
        sparkle:edSignature="[SIGNATURE_FROM_SIGN_UPDATE_SH]"
        length="[FILE_SIZE_FROM_SIGN_UPDATE_SH]"
        type="application/octet-stream"
    />
    <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
</item>
```

**Important**: Use the signature and file size from `./sign_update.sh` output!

### 6. Commit and Tag on Main Branch

```bash
# Commit version changes
git add appcast.xml
git commit -m "Prepare release v1.0.1"

# Create and push tag
git tag -a v1.0.1 -m "Release v1.0.1: [Brief description of changes]"
git push origin main
git push origin v1.0.1
```

### 7. Update Public Branch

**Note**: The `public` branch is an orphan branch (no shared history with `main`), so you need to manually copy changed files instead of merging.

```bash
# Switch to public branch
git checkout public

# Copy updated files from main branch (this automatically stages them)
git checkout main -- appcast.xml makeHTML-Swift/

# Review what changed
git status
git diff --cached  # Shows staged changes

# Commit the changes (files are already staged)
git commit -m "Release v1.0.1"

# Push to public repo (the tag already exists from step 6, so just push it)
git push public public:main
git push public v1.0.1

# Return to main branch
git checkout main
```

### 8. Create GitHub Release

1. Go to https://github.com/dmitriyuchakin/makehtml/releases
2. Click "Draft a new release"
3. Choose tag: `v1.0.1`
4. Release title: `makeHTML v1.0.1`
5. Description: Add release notes with changes/fixes
6. Attach file: Upload `makeHTML-Swift/build/makeHTML.zip`
7. Click "Publish release"

### 9. Verify Release

- Check that appcast.xml is accessible: https://raw.githubusercontent.com/dmitriyuchakin/makehtml/main/appcast.xml
- Check that release file downloads correctly from GitHub Releases
- Test auto-update in the app (if running previous version)

## Quick Reference Commands

```bash
# Build
cd makeHTML-Swift && ./build.sh && cd ..

# Get file size for appcast
ls -l makeHTML-Swift/build/makeHTML.zip | awk '{print $5}'

# Commit and tag
git commit -am "Prepare release vX.X.X"
git tag -a vX.X.X -m "Release vX.X.X: Description"
git push origin main && git push origin vX.X.X

# Update public (orphan branch - copy files manually)
git checkout public
git checkout main -- appcast.xml makeHTML-Swift/
git commit -m "Release vX.X.X"
git push public public:main && git push public vX.X.X  # Tag already exists from step 6
git checkout main
```

## Notes

- The `appcast.xml` file must be in the public repo for Sparkle updates to work
- Tags should be created on both `main` (private) and `public` branches with the same version
- Always test the build before creating a release
- Keep release notes clear and user-focused
