# DropoverClone

Native macOS shelf for files. Drag files in, drag them out somewhere else later. Free reimplementation, no Dropover code or assets used.

## Features

- Floating, always-on-top shelf (NSPanel)
- **Real file previews** — QuickLook thumbnails (images, PDFs, video, docs), not just generic icons
- Drag files in, drag files out (preserves original location — references, not copies)
- **Stack tabs** in the header with live item counts — one tap to switch
- **Hover tile actions** — lift effect, file-size label, one-click remove (×)
- **Global hotkey** ⌥⌘V to summon/dismiss the shelf anywhere
- **Pin** to keep the shelf open (suppresses auto-hide)
- **Copy All** to clipboard, plus per-item Copy Path
- **Launch at Login** toggle (menu bar)
- Menu-bar item-count badge
- Persistence between launches (security-scoped bookmarks, with stale-move recovery)
- Auto-show shelf when a file drag wiggles anywhere on screen
- Share via macOS share sheet (AirDrop / Mail / Messages / iCloud Drive link)
- Right-click items: Open, Reveal in Finder, Copy Path, Remove

## Build

```bash
cd ~/Documents/dropover-clone
./build.sh
open dist/DropoverClone.app
```

Requires macOS 13+, Swift 5.9+ (Xcode CLT installed).

## First-launch permissions

macOS may ask for permission for file access on first drop. Accept. The app stores security-scoped bookmarks so files stay accessible across launches.

For drag-detection across other apps to work, you may need to grant Accessibility permission (System Settings → Privacy & Security → Accessibility) — the global event monitor uses it.

## Why a clone vs paying

Dropover is a polished commercial app — pay if you want polish, support, sync, S3 upload, etc. This clone is a from-scratch hobby reimplementation of the core idea (file shelf + multiple stacks + share). No reverse engineering, no copied code or art.

## Roadmap

- Customizable hotkey (currently fixed at ⌥⌘V)
- iCloud public share-link integration (CKShare)
- Optional S3 upload (bring-your-own-credentials)
- Drag-reorder items within a stack
- Spacebar QuickLook preview of selected item

## License

MIT (your own code). Not affiliated with Dropover.
