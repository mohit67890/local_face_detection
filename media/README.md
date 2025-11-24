# Media Files Setup

## Required Files

Please add the following files to the `media/` directory:

1. **demo.gif** - Rename `Simulator Screen Recording - iPhone 16e - 2025-11-24 at 10.18.22.gif` to `demo.gif`
2. **screenshot1.png** - Rename `simulator_screenshot_26ED77B6-506D-46F9-B91A-DE4A0AD4FCA7.png` to `screenshot1.png`
3. **screenshot2.png** - Rename `simulator_screenshot_937F2273-C661-4623-B9E9-FCEC2F7CF4FE.png` to `screenshot2.png`

## Commands to Add Files

Run these commands from the repository root:

```bash
# Move/copy your files to the media directory
mv "Simulator Screen Recording - iPhone 16e - 2025-11-24 at 10.18.22.gif" media/demo.gif
mv "simulator_screenshot_26ED77B6-506D-46F9-B91A-DE4A0AD4FCA7.png" media/screenshot1.png
mv "simulator_screenshot_937F2273-C661-4623-B9E9-FCEC2F7CF4FE.png" media/screenshot2.png

# Add to git
git add media/
git commit -m "Add demo GIF and screenshots"
git push origin main
```

## After Adding Files

The README.md and Medium article have been updated to reference these files:
- README: Shows demo GIF at top, screenshot gallery in "See It In Action" section
- Medium article: Shows demo GIF in header, screenshots before "Basic Usage"

The files are referenced as:
- `media/demo.gif`
- `media/screenshot1.png`
- `media/screenshot2.png`
