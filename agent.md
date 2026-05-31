# AI Agent Context Memory File (agent.md)

This file serves as a persistent memory and state tracker for AI agents (like Cursor, Windsurf, Antigravity, or other LLM-based coding assistants) working on this repository. Read this file to understand the project history, architectural decisions, and current state.

---

## 1. Project Overview & State
* **Project Name**: ChocoAlign
* **Current State**: Active, fully implemented, verified, and pushed to remote origin.
* **Goal**: Scan installed Windows applications, align them with Chocolatey packages using heuristics and online validation, output to an editable CSV for user revision, and generate a `packages.config` for automated restoration/installation.

---

## 2. Key Design Decisions & Rationale

### Choice of Technology
* **PowerShell**: Used because it runs natively on Windows, has direct object-oriented registry query utilities (`Get-ItemProperty`), handles XML/CSV natively without external dependencies, and integrates perfectly with Chocolatey's native PowerShell installer hooks.

### Two-Step Workflow
To prevent automatic bulk installation of incorrectly matched packages, the tool splits execution into two phases:
1. **Mapping Phase**: Scans the Registry, guesses Choco IDs, and writes to `choco-mappings.csv`.
2. **Configuration Phase**: The user reviews/edits the CSV, sets the action for desired apps to `Include` and unwanted ones to `Ignore`, then runs the tool to produce the standard XML `packages.config`.

### Heuristics & Regex-Based Word Boundary Matching
* Standard substring matching (like `.Contains("git")`) caused false matches (e.g., matching "Alienware Digital Delivery" to `git` because "digital" contains "git").
* The tool uses regular expression word boundaries (`\b$key\b` and `\b$key(?!\w)`) to match key names. This ensures precise matching.

### Preserving User Modifications
* When generating mappings, if an existing `choco-mappings.csv` is found, the tool loads and preserves the user's manual adjustments (`ChocoPackageId` and `Action`) rather than overwriting them.

---

## 3. Directory & File Structure

* **`choco-align.ps1`**: CLI entry point. Routes parameters and formats visual logs.
* **`src/ChocoAlign.psm1`**: Module containing registry scanner, regex matching, CSV exporter, XML config generator, and installer wrapper functions.
* **`choco-mappings.csv`** *(Git-Ignored)*: User-editable mapping spreadsheet.
* **`packages.config`** *(Git-Ignored)*: Standard Chocolatey packages restore XML.
* **`.gitignore`**: Excludes `*.csv`, `*.config`, and log files.
* **`LICENSE`**: GNU General Public License v3.

---

## 4. User Preferences & Coding Standards
* **Language**: All code, comments, readme files, and documentation must be written in **English**.
* **Git Behavior**: Always automatically stage, commit, and push modifications directly after a task is completed, without waiting/prompting in chat.
* **Licensing**: Prepend the standard GPLv3 header notice to all source files.

---

## 5. Verification Commands
To check syntax and test runs:
* **Syntax validation**: `Get-Command -Syntax .\choco-align.ps1`
* **Generate Mappings scan**: `.\choco-align.ps1 -GenerateMap`
* **Generate XML config**: `.\choco-align.ps1 -GenerateConfig`
* **Simulate Installation**: `.\choco-align.ps1 -Install -DryRun`
