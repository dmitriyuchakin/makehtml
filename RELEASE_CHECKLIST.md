# makeHTML Release Checklist

Use this checklist every time you release a new version.

## Pre-Release

- [ ] All features tested and working
- [ ] No known critical bugs
- [ ] Documentation updated (if needed)
- [ ] CHANGELOG updated (if you maintain one)

## Version Updates

- [ ] Update `APP_VERSION` in `makeHTML-Swift/build.sh`
- [ ] Update `BUILD_NUMBER` in `makeHTML-Swift/build.sh`
- [ ] Update version in About panel (makeHTMLApp.swift line 32) if needed

## Build

```bash
cd makeHTML-Swift
./build.sh
```

- [ ] Build completed successfully
- [ ] Test the built app manually:
  - [ ] Convert a DOCX file
  - [ ] Preview looks correct
  - [ ] Reload button works
  - [ ] Reset button works
  - [ ] Open HTML in VSCode works
  - [ ] Config folder opens
  - [ ] Edit config.json opens in TextEdit

## Create Release Archive

```bash
cd build
zip -r makeHTML-X.X.zip makeHTML.app
```

- [ ] ZIP file created
- [ ] Test extracting the ZIP to ensure it works

## Sign the Update

```bash
cd ..
./sign_update.sh build/makeHTML-X.X.zip
```

- [ ] Copy the **signature** output
- [ ] Copy the **file size** output

## Create GitHub Release

- [ ] Go to https://github.com/YOUR_USERNAME/YOUR_REPO/releases
- [ ] Click "Create a new release"
- [ ] Tag version: `vX.X` (e.g., `v0.6`)
- [ ] Release title: `Version X.X`
- [ ] Write release notes describing:
  - [ ] New features
  - [ ] Bug fixes
  - [ ] Breaking changes (if any)
- [ ] Upload `makeHTML-X.X.zip`
- [ ] Publish release

## Update appcast.xml

- [ ] Open `appcast.xml`
- [ ] Copy the example `<item>` block
- [ ] Update:
  - [ ] Title
  - [ ] Version numbers (both places)
  - [ ] Description/release notes
  - [ ] Publication date (use `date -R` for correct format)
  - [ ] Download URL (match GitHub release)
  - [ ] Signature (from sign step)
  - [ ] File size (from sign step)
- [ ] Verify all URLs are correct
- [ ] Save file

## Publish

```bash
git add appcast.xml
git add makeHTML-Swift/build.sh  # if you changed version
git commit -m "Release version X.X"
git push origin main
```

- [ ] Changes pushed to GitHub
- [ ] appcast.xml is accessible at the SUFeedURL

## Test Update Mechanism

- [ ] Open the **previous version** of makeHTML
- [ ] Go to makeHTML menu → "Check for Updates..."
- [ ] Verify it detects the new version
- [ ] Verify release notes display correctly
- [ ] Test the update installation
- [ ] Verify the updated app works correctly

## Announce (Optional)

- [ ] Post on social media / blog / etc.
- [ ] Notify users via email list (if you have one)
- [ ] Update website download link (if applicable)

## Common Issues

**Update not detected:**
- Wait 30 seconds for GitHub to propagate
- Check appcast.xml is accessible in browser
- Verify version number is higher than current

**Signature invalid:**
- Regenerate signature with correct private key
- Ensure .zip wasn't modified after signing

**Download fails:**
- Check GitHub release is published (not draft)
- Verify URL in appcast.xml matches release

---

## Quick Commands Reference

```bash
# Build
cd makeHTML-Swift && ./build.sh

# Create ZIP
cd build && zip -r makeHTML-X.X.zip makeHTML.app

# Sign
./sign_update.sh build/makeHTML-X.X.zip

# Get current date in RFC 822 format
date -R

# Test appcast accessibility
curl https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/appcast.xml

# Clear Sparkle cache (for testing)
defaults delete com.makehtml.converter SULastCheckTime
```
