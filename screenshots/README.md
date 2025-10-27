# Screenshots

This folder contains app screenshots for the GitHub README.

## How to Add Screenshots

### 1. Take a Screenshot from Xcode Simulator

1. Run the app in Xcode (Cmd + R)
2. Navigate to the main wallet view
3. Press **Cmd + S** in the simulator window
4. Screenshot will be saved to your Desktop

### 2. Add Screenshot to This Folder

1. Rename your screenshot to `demo.png`
2. Copy it to this `screenshots/` folder:
   ```bash
   cp ~/Desktop/screenshot.png ./screenshots/demo.png
   ```

### 3. Optimize the Image (Optional)

For better loading on GitHub:
```bash
# Resize to 600px width (maintains aspect ratio)
sips -Z 600 screenshots/demo.png
```

### 4. Commit and Push

```bash
git add screenshots/demo.png
git commit -m "Add app screenshot"
git push origin main
```

## Recommended Screenshots

For a complete showcase, consider adding:

- `demo.png` - Main wallet view (already referenced in README.md)
- `wallet-creation.png` - Wallet creation flow
- `nft-gallery.png` - NFT gallery view
- `token-swap.png` - Token swap interface
- `settings.png` - Settings screen

## Image Requirements

- **Format**: PNG or JPG
- **Width**: 300-800px (600px recommended)
- **Aspect Ratio**: 19.5:9 (iPhone screen ratio)
- **File Size**: < 500KB per image

---

**Current Status**: ⏳ Waiting for screenshots to be added

Once you add `demo.png`, it will automatically appear in the main README.md!
