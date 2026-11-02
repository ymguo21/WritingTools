# Writing Tools

**System-wide AI writing and screen-reading tools for macOS, built for people who write machine-learning papers and code.**

Select text in any app, press a shortcut, and proofread it, review every edit word by word, translate it, or summarize it. Drag a box around anything on screen and turn a formula into LaTeX or a paragraph into a translation. Bring your own model: cloud, a local server, or fully on-device.

> **About this repository.** This is an independent fork of [theJayTea/WritingTools](https://github.com/theJayTea/WritingTools) by Jesai Tarun, built on the native macOS port by [Arya Mirsepasi](https://github.com/Aryamirsepasi). Development here continues on macOS only, with its own bundle ID (`com.ymguo21.writing-tools`), its own releases and its own update checks. See [Credits](#credits) for everyone whose work it stands on.

---

## What's new in this fork

These are the features added on top of the original macOS app. Full details are in the [macOS README](macOS/README.md).

### Read the screen

Both commands start with a drag-to-select crosshair, send the region to the cloud model you already configured, and open a window with the result. They need **Screen Recording** permission and a model that accepts images (OpenAI, Gemini, Anthropic and compatible endpoints; not Mistral, Ollama in OCR mode or text-only local models). With nothing selected, the popup offers just these commands.

- **Formula OCR**: a formula on screen becomes LaTeX Markdown. The window shows a rendered preview next to the source, with a **Copy** button for the source. The preview rewrites LaTeX the renderer rejects and falls back to showing code, so it is never blank. The text you copy is never rewritten.
- **Screenshot Translate**: shows the recognized text and its translation one above the other, each with its own **Copy** button, and streams the translation as it is written. Chinese becomes English; anything else becomes Simplified Chinese.

### Edit with control

- **Review Mode**: see every change word by word, Grammarly-style, and accept or reject each one before anything touches your text. Switch between Markup, Final and Original, and ask for an explanation of any edit on request.
- **Grammar Check**: an English editor for machine-learning papers and code. It fixes grammar, spelling, punctuation and word choice, translates Chinese fragments (or all-Chinese input) into English, and smooths stiff wording with phrase-level edits. Code, LaTeX, citations, numbers, hyperparameters and the names of models, datasets and libraries are left alone, and so is the strength of your claims. It opens in Review Mode and streams its reply while it is being written.
- **Translate**: Chinese or mixed text goes to English, everything else to Simplified Chinese. Technical terms (Transformer, fine-tuning, LLM...) stay in English, and code and formulas are kept; only comments and docstrings are translated. The result opens in a window, so your original text is never overwritten.

### Your own command list

- **Choose and order commands**: Settings → Commands is one list of built-in and custom commands. Untick a command to hide it from the popup (its shortcut keeps working) and drag to reorder.

---

## Install (macOS)

1. Download the latest `WritingTools-<version>.zip` from [Releases](https://github.com/ymguo21/WritingTools/releases).
2. Unzip it and drag `WritingTools.app` into Applications.
3. The build is ad-hoc signed and not notarized, so the first launch is blocked. Open **System Settings → Privacy & Security** and click **Open Anyway**.
4. Grant **Accessibility** (to read and replace selected text). Formula OCR and Screenshot Translate also need **Screen Recording**.
5. Open Settings, choose an AI provider, enter your own API key and set a shortcut.

Requires macOS 14 or later; the build is universal (Apple Silicon and Intel). iCloud command sync is off in this build. After installing an update you may need to grant Accessibility again, because a new ad-hoc signature counts as a new app.

---

## The basics

Everything the original app does is still here.

- **Use it anywhere.** Select text in almost any app, press your shortcut and pick an action. The result replaces your text (undo in the app to revert).
  - **Proofread** (keeps rich-text formatting), **Rewrite**, **Friendly**, **Professional**, **Concise**
  - **Summary**, **Key Points** and **Table**, shown in a window with Markdown rendering that you can chat with
  - **Custom instructions** in `Describe your change...` (for example "add comments to this code" or "translate to French")
- **Chat any time.** Press the shortcut with nothing selected to talk to your model. History is deleted when you close the window.
- **Your own buttons.** Create commands from your own prompts, give each its own shortcut, and even its own provider and model.
- **Images.** Select an image and send it to a vision-capable model together with your text.
- **Many languages.** Commands work in any language the model does; the interface is available in English, German, French and Spanish.
- **Themes**, including dark mode.

### Models

- **Cloud:** OpenAI, Google Gemini, Anthropic, Mistral, OpenRouter, and any OpenAI-compatible endpoint (custom base URL).
- **Local:** Ollama, or **MLX** on Apple Silicon for fully on-device inference, with no internet needed.

You can mix them: keep sensitive work on-device and use a large cloud model when you need it.

To use Ollama through the OpenAI-compatible provider: install [Ollama](https://ollama.com/download), run `ollama pull llama3.1:8b`, then in Settings choose the OpenAI provider with API key `ollama` (any string works), base URL `http://localhost:11434/v1` and model `llama3.1:8b`.

### Privacy

- The app collects no logs, analytics or ads. Text and screenshots are sent only to the provider you chose, and only when you run a command.
- API keys are stored on your device, in the Keychain.
- With a local model, nothing leaves your Mac. With a cloud model, the provider's privacy policy applies.

### Troubleshooting

- **Shortcut does nothing, or the popup shows only the screen commands.** The app could not copy your selection. Check that **Accessibility** is allowed for Writing Tools; if it is already on, remove it with **−** and add the app again.
- **Shortcut conflicts.** Pick another combination in Settings, and check Spotlight and Input Sources under System Settings → Keyboard → Keyboard Shortcuts.
- **Screen commands say Screen Recording is needed.** Allow Writing Tools under Privacy & Security → Screen Recording and restart the app.
- **Local model not answering.** Make sure Ollama is running and the base URL and model name match, or that the MLX model is downloaded and selected.

More in the [macOS README](macOS/README.md), including how to build from source in Xcode.

---

## Windows and Linux

The original Windows and Linux app by Jesai Tarun lives in [`Windows_and_Linux/`](Windows_and_Linux). It is kept as it was in the upstream project and is not developed in this fork. For its releases, instructions and issues, use the [upstream repository](https://github.com/theJayTea/WritingTools):

- [Run it from the source code](README's%20Linked%20Content/To%20Run%20Writing%20Tools%20Directly%20from%20the%20Source%20Code.md)
- [Compile it yourself](README's%20Linked%20Content/To%20Compile%20the%20Application%20Yourself.md)

---

## About the original project

Writing Tools began as an Apple Intelligence-inspired app for Windows and Linux that lets any LLM proofread, rewrite and summarize text system-wide. It was a top-10 trending AI project on GitHub in October 2024 and has been covered by [30+ publications](Media%20Coverage.md) ([Beebom](https://beebom.com/high-schooler-app-brings-apple-inteligence-writing-tools-windows/), [XDA](https://www.xda-developers.com/windows-pc-can-now-deliver-instant-free-writing-help-across-all-apps/), [How-To Geek](https://www.howtogeek.com/if-you-like-apple-intelligences-writing-tool-try-this-open-source-app-as-its-windows-counterpart/), [Neowin](https://www.neowin.net/news/apple-intelligence-writing-tools-for-windows-get-new-summarization-features-and-more/), [Windows Central](https://www.windowscentral.com/software-apps/can-apple-catch-up-apple-intelligence-just-shipped-yet-free-apple-writing-tools-on-github-for-windows-and-linux-make-a-better-alternative)...). Its original demos are in the [upstream README](https://github.com/theJayTea/WritingTools#readme).

If you find value in the original work, please consider supporting its authors:

- **Jesai Tarun** (original app, Windows and Linux): [Buy Me a Coffee](https://www.buymeacoffee.com/jesaitarun)
- **Arya Mirsepasi** (macOS port): [Buy Me a Coffee](http://buymeacoffee.com/aryamirsepasi)

---

## Credits

**Original project**: created by [Jesai Tarun](https://github.com/theJayTea), with thanks to everyone who contributed to it:

- [momokrono](https://github.com/momokrono): Linux support, the pynput switch for Windows stability, Ollama support, the core of customisable buttons, localization, and a great deal of issue management.
- [Cameron Redmore](https://github.com/CameronRedmore): a major refactor, OpenAI-compatible API support, streamed responses and the chat mode.
- [Soszust40](https://github.com/Soszust40): dark mode, the plain theme, tray menu fixes and UI work.
- [Alok Saboo](https://github.com/arsaboo): more reliable text selection.
- [raghavdhingra24](https://github.com/raghavdhingra24): anti-aliased rounded corners.
- [ErrorCatDev](https://github.com/ErrorCatDev): the scrollable About window, `.gitignore` and `requirements.txt`.
- [Vadim Karpenko](https://github.com/Vadim-Karpenko): the start-on-boot setting.

**macOS app**: a native Swift port created by [Arya Mirsepasi](https://github.com/Aryamirsepasi), with:

- [Joaov41](https://github.com/Joaov41): image processing with Gemini.
- [drankush](https://github.com/drankush): the fix for OpenAI providers with a custom base URL.
- [gdmka](https://github.com/gdmka): remembered text size in the response window, and a provider per command.

**Libraries**: [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus, [MLX Swift](https://github.com/ml-explore/mlx-swift) for on-device models, [MarkdownView](https://github.com/LiYanan2004/MarkdownView) and SwiftMath for rendering.

**This fork**: [Yaming GUO](https://github.com/ymguo21).

## Contributing

Issues and pull requests are welcome at [ymguo21/WritingTools](https://github.com/ymguo21/WritingTools). For bugs in the Windows and Linux app, use the [upstream repository](https://github.com/theJayTea/WritingTools).

## License

Distributed under the GNU General Public License v3.0, like the original project. See [LICENSE](LICENSE).

**Modification notice.** This is a modified version of Writing Tools. The macOS app was created by Arya Mirsepasi on top of the project by Jesai Tarun, and Yaming GUO has modified it since 25 October 2026. Every change, with its date and author, is in the [git history](https://github.com/ymguo21/WritingTools/commits/main).

**Source code.** The complete source of each release is the matching tag of this repository, for example [v6.3](https://github.com/ymguo21/WritingTools/tree/v6.3).

**Third-party software.** The app is built with open-source Swift packages under their own licenses; their notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
