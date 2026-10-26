# Writing Tools for macOS (Native Swift Port)

> System-wide AI writing superpowers for Mac — **native Swift**, **privacy-first**, and **insanely fast** on Apple Silicon.

[Back to root README](../README.md)

---

## Table of Contents
- [What's New in This Fork](#whats-new-in-this-fork)
- [Review Mode](#review-mode)
- [Highlights](#highlights)
- [Quick Start (Download & Install)](#quick-start-download--install)
- [First Launch: Permissions](#first-launch-permissions)
- [Using Writing Tools](#using-writing-tools)
- [Providers & Models](#providers--models)
- [Power Features](#power-features)
- [System Requirements](#system-requirements)
- [Build From Source (Xcode)](#build-from-source-xcode)
- [Troubleshooting](#troubleshooting)
- [Privacy](#privacy)
- [Credits](#credits)
- [License](#license)

---

## What's New in This Fork

- **Review Mode**: see every change word by word, Grammarly-style, and accept or reject each one before it touches your text. See [Review Mode](#review-mode).
- **Grammar Check** (built-in command): an English editor for machine-learning papers and code. It fixes grammar, spelling, punctuation and word choice, translates Chinese fragments into English, and smooths stiff wording with phrase-level edits. Code, LaTeX, citations, numbers, hyperparameters and model or library names are left alone, and so is the strength of your claims. Opens in Review Mode.
- **Translate** (built-in command): text with any Chinese characters (Chinese or mixed Chinese/English) is translated into English; anything else into Simplified Chinese. When translating into Chinese, ML terms (Transformer, fine-tuning, LLM...) and names of models, datasets and functions stay in English. Code and formulas are kept; only comments and docstrings are translated. The result opens in a window, so your original text is never overwritten.
- **Choose and order commands**: **Settings → Commands** is one list of built-in and custom commands. Untick a command to hide it from the popup (its keyboard shortcut keeps working) and drag to reorder.
- **macOS 27**: the Privacy & Security links open System Settings again.

---

## Review Mode

Any command can show its changes for review instead of pasting them right away. Turn it on per command: **Settings → Commands → edit a command → Result: Review changes first**. Grammar Check uses it by default.

1. Select text and run the command. The model returns the revised text, and Writing Tools computes a **word-level diff** on your Mac.
2. Each edit starts as **pending**: the deleted words in red strikethrough, the new words in green.
3. **Accept** (✓ or Return) shows only the new text, with a faint green underline. **Reject** (✗ or Delete) restores the original. The next pending edit is selected automatically, and reviewed edits collapse to one line with **Undo**.
4. Switch the text between **Markup**, **Final** (exactly what will be written back) and **Original**. Hold **⌥ Option** to peek at the original.
5. **Apply** (⌘↩) writes the result back into the app you came from, keeping the formatting between edits. Pending edits count as accepted. **Copy** puts the result on the clipboard instead.

**Explain edits on request** (optional, per command, only with Review Mode): ask for an explanation of one edit or all of them, or type a follow-up question about the changes. Nothing is sent to the model until you ask. Set the explanation language under **Settings → General → Review Mode** (default: Simplified Chinese).

---

## Highlights

- **Truly native**: Built in Swift (SwiftUI + AppKit where helpful) for a crisp Mac experience.
- **Local LLMs with MLX**: Run models **fully on-device** on Apple Silicon. No internet required.
- **Rich Text Proofread**: Keep **RTF formatting** (bold, italics, lists, links) while fixing grammar and tone.
- **Your workflow, your rules**: Add/edit **custom commands** and assign your own **shortcuts**.
- **Multilingual**: App UI in **English, German, French, Spanish**; commands work with many more languages.
- **Themes**: Multiple themes including Dark Mode to match your desktop.

---

## Quick Start (Download & Install)

1) **Download** the latest `WritingTools-<version>.zip` from **Releases**:  
   https://github.com/ymguo21/WritingTools/releases

2) **Install**  
   - Unzip it and drag **WritingTools.app** into **Applications**.
   - This build is ad-hoc signed, not notarized, so macOS blocks the first launch. Open **System Settings → Privacy & Security** and click **Open Anyway**, or run `xattr -dr com.apple.quarantine /Applications/WritingTools.app` in Terminal.
   - iCloud command sync is not available in this build. After installing an update, you may need to grant **Accessibility** again.

3) **Run**  
   - Launch the app.
   - Open **Settings** and choose your **AI Provider** (local MLX, Ollama, or a cloud provider).
   - Assign your preferred **keyboard shortcut**.

---

## First Launch: Permissions

Writing Tools uses macOS accessibility to read and replace selected text.  
On first run, grant:

- **Accessibility** (required)  
- **Screen Recording** (only needed for some apps that restrict text access)

You can manage these anytime under:  
**System Settings → Privacy & Security → Accessibility / Screen Recording**.

> Tip: If replacement doesn’t work in a specific app, enabling **Screen Recording** usually fixes it.

---

## Using Writing Tools

- **Invoke anywhere**: Select text in any app → press your shortcut → choose an action:
  - **Proofread** (keeps RTF formatting)
  - **Grammar Check** (reviewed word by word) and **Translate**
  - **Rewrite**, **Make Friendly**, **Make Professional**, **Concise**
  - **Summarize**, **Key Points**, **Table**
  - **Custom command** (your own prompt)
- **No selection?** Your shortcut opens a quick **Chat** with the current model.
- **Undo**: If you don’t like the result, simply undo in the target app.

> Shortcut conflicts? Check **System Settings → Keyboard → Keyboard Shortcuts** (Spotlight/Input Sources) and pick an alternative combo in the app’s Settings.

---

## Providers & Models

- **Cloud**: OpenAI, Google (Gemini), Anthropic, Mistral, OpenRouter  
- **Local**:
  - **MLX (Apple Silicon)** — first-class, on-device inference
  - **Ollama** via OpenAI-compatible endpoint

Bring your own API keys, switch providers anytime, and mix local + cloud based on your task.

---

## Power Features

- **Command Editor**: Create reusable buttons for your own prompts; assign per-command shortcuts.
- **Model Flexibility**: Choose the best model for proofreading vs. summarization vs. chat.
- **Localization**: UI in **EN / DE / FR / ES**; commands happily accept and output many languages.
- **Document-friendly**: **RTF-preserving Proofread** keeps the look of your document intact.

---

## System Requirements

- **macOS 14.0 or later** (due to Accessibility APIs used for selection/replacement).  
- **Apple Silicon** recommended for MLX local models (runs on-device for privacy and speed).  
- For development: **Xcode 15+**.

---

## Build From Source (Xcode)

You can build the macOS app either by opening the project or the package:

**Option A — Open project (if present)**  
1. `git clone https://github.com/ymguo21/WritingTools.git`  
2. Open **WritingTools/macOS/** and double-click the **.xcodeproj**.  
3. Select target **Writing Tools** → **Signing & Capabilities** → choose your Development Team.  
4. Set **Deployment Target** to **macOS 14.0** (or higher).  
5. Run on **My Mac** (⌘R).

**Option B — Open the folder / Package.swift**  
1. `git clone https://github.com/ymguo21/WritingTools.git`  
2. In Xcode: **File → Open…** → choose **WritingTools/macOS** (or the repo root).  
3. Let Xcode resolve Swift Packages, then configure **Signing** and **Deployment Target** as above.  
4. Run on **My Mac** (⌘R).

> First debug run will trigger macOS permission prompts (Accessibility / Screen Recording). Accept them and relaunch if prompted.

---

## Troubleshooting

- **Shortcut doesn’t trigger**  
  - Pick another combo in Settings (avoid Spotlight/Input Sources defaults).
- **Text not replaced in a specific app**  
  - Ensure **Accessibility** is allowed; enable **Screen Recording** for that app scenario.
- **Local model not responding**  
  - For **MLX**: confirm the model is available and selected in Settings.  
  - For **Ollama**: verify the server is running and the **Base URL / Model** fields match your local model name.
- **Permissions got reset**  
  - Remove and re-add the app under: **System Settings → Privacy & Security**.

---

## Privacy

- Nothing is sent anywhere unless **you** invoke an action.
- API keys are stored **locally** on your device.
- Use **MLX** to keep all processing **on-device** (no network).

---

## Credits

- **macOS Port**: **Arya Mirsepasi** 
- **Gemini Image/Picture Processing**: **Joaov41**. 
- **OpenAI Compatible API Fix**: **drankush**
- **Text size fix and per command provider**: **gdmka**
- **Keyboard Shortcuts**: Thanks to **sindresorhus/KeyboardShortcuts**.  
- **MLX Swift** (local LLMs on Apple Silicon): https://github.com/ml-explore/mlx-swift-examples



## License

Distributed under the **GNU GPL v3**.
