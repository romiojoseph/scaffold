# Scaffold
A Flutter Windows developer utility for project exploration, code analysis, and other development workflows.

### About
Scaffold started as a simple PowerShell script. The original purpose was to quickly generate project structures and collect useful information that could be shared with AI tools. The script was converted into a desktop application as an experiment. The goal was simple. A simple UI for a few commands I mostly use.
Over time, more features were added, turning it into a lightweight project explorer and analysis tool.

> This is a vibe-coded project, built entirely with AI assistance. I handled the design and UX myself, while the logic was AI-generated and refined through iterative prompting. Use it or fork it.

*If you are going to clone and build this app yourself, make sure to download a `tokenizer.json` from huggingface (not included because of the file size). I used this one [https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731/tree/main](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731/tree/main)

---

### Source Code Distribution
This repository contains the source code only. Pre-built Windows executables, installers, or ZIP releases are not provided.
**The source code is shared so developers (even a non dev can build with the help of AI) can:**
* Inspect the implementation
* Understand the approach
* Experiment with the application
* Modify features
* Build their own version

You can build the application locally using Flutter Windows.

---

### Features

#### Project Scanner
Scan any project directory and analyse its structure.
**Provides information about:**
* Files
* Folders
* File types
* Directory structure
* Line counts
* Code statistics

---

### Multiple Output Views

#### Tree View
Visual representation of the scanned project structure.
**Useful for:**
* Understanding unfamiliar repositories without opening an IDE
* Reviewing project organisation
* Sharing project context

#### ASCII View
Generate a text-based project structure.
**Useful for:**
* AI prompts
* Documentation
* Code reviews
* Project discussions

ASCII output can be copied or trimmed down to the base.

---

#### Code Statistics
The statistics view provides detailed project analysis.
* Total files
* Total lines
* Code lines
* Comment lines
* Blank lines
* Language-wise breakdown
* Individual file statistics
* Estimated token count (experimental feature) - based on `tokenizer.json` downloaded from huggingface (deepseek-ai/DeepSeek-V4-Flash-0731) and then used `https://pub.dev/packages/hf_tokenizers`.

The generated table can be copied as Markdown and used directly in documentation or AI tools.

**Example use cases:**
* Understanding project size
* Finding large files
* Reviewing code distribution
* Planning refactoring

*For counting code, the binary built with Tokei (cargo install --git https://github.com/XAMPPRocky/tokei.git tokei) is used. It has been added to assets\third_party\tokei\tokei.exe.*

---

### File Line Threshold
Set custom limits for file sizes. The purpose is to identify files that have become too large and may need refactoring.
**Example:**
```
TSX files: 600 lines
Dart files: 500 lines
```
Files exceeding the configured threshold will be highlighted for review. Threshold values are completely customisable based on personal workflow preferences.

---

### Exclusion Management
Control which files and folders are included during scanning.

#### Custom Exclusions
Add files, folders, or path-based patterns.
**Examples:**
```
*.log
node_modules
build
windows/flutter
build/flutter_assets
```

Patterns can be:
- **Bare names** — match any file or folder with that name anywhere in the tree (e.g. `build`, `*.log`)
- **Path-based** — match only at a specific location relative to the scanned root (e.g. `windows/flutter`, `build/flutter_assets`)
- **Extensions** — patterns starting with `.` match by extension (e.g. `.svg`, `.png`)

Both `/` and `\` are accepted as path separators and are treated identically.

#### Presets
Includes presets for common development environments:
* General
* Web
* Flutter
* Python
* Rust
* Go
* Kotlin
* Docker

#### Exclusion Engine Toggle
Enable or disable the manual exclusions list independently. When disabled, all manually configured patterns are skipped during scanning.

#### Git Ignore Mode
Optionally scan using `.gitignore` rules from the project root. When enabled, gitignore patterns are applied in addition to any manual exclusions that are configured. The manual exclusion engine toggle still applies — if it is off, only gitignore rules are used.

> The `.gitignore` file must exist in the scanned root directory. If it is not found, gitignore mode is automatically turned off.

---

### Directory History
All project paths are stored in history.
**Features:**
* Add multiple directories
* Quickly reopen previous locations
* Clear history when required

**From a selected directory you can:**
* Open Windows Explorer
* Open terminal

---

### Export
Scan results can be exported as a structured JSON file.
**The exported file includes:**
* Root path and folder name
* Scan date
* Active exclusion patterns
* Full directory structure with file metadata

This is useful for archiving snapshots, sharing project structure, or comparing state over time.

---

### Snapshot Compare
Scaffold supports comparing project snapshots over time.
**Workflow:**
1. Scan a project
2. Export the scan result as JSON
3. Continue development
4. Scan again later
5. Compare snapshots

This helps understand changes between two points in a project's development.

---

### JSON File Viewer
Scaffold can be configured as the default application for JSON files. This allows quick inspection of JSON files without opening a full IDE. And there's an option to view and copy the skeleton schema of the selected JSON. (A limit is set for JSON files, and it is 30 MB for now).

**Ways to open a JSON file:**
* Double-click a `.json` file in Explorer (when set as default app)
* Use the Open JSON button in the title bar
* Click any `.json` while viewing in Tree View mode

---

### Windows Integration

#### Folder Context Menu
Scaffold can be added to the Windows folder context menu.
After enabling it:
```
Right Click Folder → Show More Options → Open with Scaffold
```
Windows 11 places custom shell integrations inside "Show More Options" unless deeper shell integration is implemented.

#### Set as Default for JSON Files
Scaffold can register itself as the default handler for `.json` files via the Windows registry. This can be enabled or disabled from Settings.

---

#### Application Data
Application data is stored inside the Windows AppData directory. A shortcut is available from Settings to open the application data folder directly.

**Stored data includes:**
* Exclusion patterns
* Line threshold configuration
* Path history

---

### File Type Distribution
View project composition based on file types.
**Shows:**
* File extensions
* Number of files
* Distribution of project formats

Useful for quickly understanding the technology mix of a repository.

---

### Technology Stack
**Built with:**
* Flutter
* Dart
* Flutter Windows Desktop

**Key dependencies:**
* `bitsdojo_window` / `window_manager` — custom window chrome
* `file_picker` — file open dialogs
* `path_provider` — app data directory resolution
* `flutter_svg` — SVG icon rendering
* `google_fonts` — typography
* `intl` — number and date formatting

---

### Project Structure
```
lib/
├── models/
│   ├── Data models and configuration classes
│   └── Scan, exclusion, threshold, and diff models
│
├── screens/
│   └── Main application screens
│
├── services/
│   ├── File scanning logic
│   ├── Export functionality
│   ├── Icon mapping
│   └── Windows shell integration
│
├── theme/
│   ├── App colours
│   ├── Typography
│   ├── Spacing
│   └── Theme configuration
│
├── utils/
│   └── Shared utility functions
│
├── widgets/
│   ├── common/
│   │   └── Reusable UI components
│   │
│   ├── viewers/
│   │   └── File and JSON viewers
│   │
│   └── Application-specific UI components
│
└── main.dart

assets/
├── icons/
├── mapping/
└── AppIcon.png

test/
└── Widget tests
```

---

### Build From Source

#### Requirements
* Flutter SDK
* Windows development environment
* Visual Studio with Windows desktop development tools

#### Tokenizer Setup (Required for Token Estimation)
To calculate accurate byte-exact token counts, download the HuggingFace `tokenizer.json` file for your model (e.g. DeepSeek / Llama / GPT) and place it at:

```
assets/third_party/tokenizer/tokenizer.json
```

*(Note: `tokenizer.json` is excluded from git version control due to file size).*

#### Install Dependencies
```bash
flutter pub get
```

#### Run
For development, use your preferred IDE's Flutter debug mode instead of running through the terminal.

**IDE-powered debugging provides:**
- Instant hot reload
- Hot restart support
- Integrated debugging tools
- Faster development iteration

**Recommended workflow:**
- Open the project in your Flutter-supported IDE.
- Select the Windows device target.
- Start the application using the IDE's Run/Debug option.

#### Build Windows Application
```bash
flutter build windows
```
After building, go to `build\windows\x64\runner\Release\` and copy the entire Release folder to a permanent location, for example `C:\Tools\Scaffold`, and run it from there.

---

### Current Status
This application was created mainly around personal development workflows. The future direction depends on continued usage and real-world needs. Features may continue to evolve as more problems are discovered during regular development work.

---

### License
This project is shared as source code for learning, experimentation, modification, and personal development workflows. Refer to the repository license for usage details.
