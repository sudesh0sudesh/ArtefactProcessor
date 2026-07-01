# KAPE/gkape-style Windows artefact processor for macOS

## Goal

Build a macOS-native processor that parses already-acquired Windows forensic artefacts using a KAPE/gkape-inspired workflow while reusing community KAPE module definitions and Eric Zimmerman parser tooling wherever licensing and platform constraints allow.

This project is explicitly **not** a collector. It does not image, mount, copy, triage, or acquire artefacts from evidence sources. The processor expects users to provide an existing artefact directory that was collected by another trusted workflow.

The first milestone is a command-line processor. A later milestone can add a gkape-style graphical profile builder and run monitor for processing jobs only.

## Inputs and operating modes

### Supported processing inputs

- A directory containing previously acquired Windows artefacts.
- A KAPE-style module parsing profile from `Modules/` definitions.
- A custom local module overlay that maps parsers to the local macOS tool registry.

### Processor modes

1. **Process**: run compatible parser modules against an existing artefact directory.
2. **Validate profiles**: lint module definitions, resolve variables, and preview the parser execution plan without running tools.
3. **Tool doctor**: verify configured Eric Zimmerman tools, runner availability, versions, and macOS compatibility.
4. **Report**: summarize a previous processing run from its manifest and logs.

## External definition sources

The processor should support a local, pinned checkout of `sudesh0sudesh/KapeFiles`, which is a fork of `EricZimmerman/KapeFiles`, for KAPE `Modules/` definitions. Target definitions can be present in the checkout, but this project should ignore target collection definitions unless they are needed only as metadata for explaining module expectations. The KapeFiles repository describes itself as community-created targets and modules for KAPE, includes `Targets` and `Modules` folders, and notes that the latest files are normally synced through gkape or `kape.exe --sync`.

Implementation requirements:

- Store the configured KapeFiles checkout path in processor settings.
- Record the KapeFiles commit SHA in every processing manifest for repeatability.
- Treat KapeFiles as read-only input; custom local module definitions should live in a separate overlay directory.
- Add an update command that fetches the configured remote and reports changed module definitions before users opt in to a new revision.
- Preserve upstream license notices in packaged distributions.
- Do not implement KAPE target collection behavior in this project.

## Eric Zimmerman tooling strategy

The default execution path is **native .NET on macOS**. Users who want the processor to execute Eric Zimmerman tools must download the published tool zips from Eric Zimmerman's tool distribution site, or clone/build the relevant Eric Zimmerman GitHub repositories themselves, and then register the resulting binaries in the local tool registry. The processor should not silently fetch or execute tools during a case run.

Supported source links for the instruction set:

- Eric Zimmerman tools index: <https://ericzimmerman.github.io/>
- Get-ZimmermanTools helper: <https://github.com/EricZimmerman/Get-ZimmermanTools>
- EvtxECmd source repository: <https://github.com/EricZimmerman/evtx>

The repository includes `scripts/bootstrap-eztools-macos.sh` as a guided bootstrap script. By default it prints instructions only. With `--download`, it downloads `Get-ZimmermanTools.ps1` and runs it through PowerShell so users can stage the published native .NET tool builds before executing processing jobs.

Execution strategy:

1. **Native .NET execution only for the default MVP**: prefer the published .NET builds under the user-configured tools directory.
2. **User-managed source builds**: allow advanced users to point the registry at binaries produced from cloned Eric Zimmerman repositories.
3. **Skip with explanation**: if a module cannot run natively on macOS, mark it as skipped with the missing capability and remediation.

The module runner should not assume that every KAPE module is executable on macOS. Each parser should be mapped to a `ToolCapability` record that declares supported runner types, expected binary paths, version command, input/output conventions, input artefact expectations, upstream project URL, download instructions, and known macOS limitations. All Eric Zimmerman tools should eventually have registry entries, even if an entry starts as `planned` or `unsupported-on-macos`; the first implemented parser target is EvtxECmd for Windows Event Log (`.evtx`) artefacts.

## Proposed architecture

```text
+-------------------+       +--------------------+
| CLI / future GUI  | ----> | Run orchestrator   |
+-------------------+       +--------------------+
                                  |        |
                                  |        v
                                  |   +----------------+
                                  |   | Module runner  |
                                  |   +----------------+
                                  v
+-------------------+       +--------------------+
| Module resolver   | ----> | Artefact input map |
+-------------------+       +--------------------+
          |
          v
+-------------------+
| KapeFiles adapter |
+-------------------+
```

### Core components

- **KapeFiles adapter**: reads `.mkape`, compound modules, variables, categories, and metadata from upstream and local overlay definitions.
- **Module resolver**: expands user-selected modules into a deterministic parser execution plan.
- **Artefact input map**: maps parser input variables to paths inside the user-supplied artefact directory without copying or acquiring source evidence.
- **Module runner**: executes compatible parser modules, captures stdout/stderr/exit status, and writes structured parser outputs.
- **Tool registry**: maps KAPE module binaries to Eric Zimmerman tool installations and runner capabilities.
- **Processing manifest**: captures artefact root, selected modules, expanded parser graph, KapeFiles revision, tool versions, output hashes, timestamps, and skipped work.
- **Report writer**: emits JSON and human-readable processing summaries.

## Data model

### Processor configuration

```yaml
kape_files:
  path: /opt/artefactprocessor/KapeFiles
  remote: https://github.com/sudesh0sudesh/KapeFiles.git
  revision: <commit-sha>

module_overlays:
  - ~/.artefactprocessor/modules

tools:
  registry: ~/.artefactprocessor/tools.yaml
  eztools_root: ~/.artefactprocessor/eztools/net9
  runners:
    dotnet: /usr/local/bin/dotnet

output:
  default_root: ~/ArtefactProcessorRuns
```

### Processing manifest

Every run should produce `manifest.json` containing:

- Processor version and host OS details.
- Input artefact directory path and summary metadata.
- KapeFiles remote, branch, and commit SHA.
- Selected modules and expanded parser execution graph.
- Parser command lines with sensitive paths redacted where appropriate.
- Parser versions, exit codes, output locations, output hashes, and skip reasons.
- Warnings for missing expected artefacts, incompatible parser modules, or unresolved variables.

## Initial EvtxECmd capability

EvtxECmd is the first parser capability to implement. The processor should support these inputs and outputs first:

- Input: one `.evtx` file or a directory tree containing `.evtx` files inside the user-supplied artefact directory.
- Tool: `EvtxECmd` from the published Eric Zimmerman .NET tool zip, or a user-compiled binary from `EricZimmerman/evtx`.
- Output: CSV and JSON output directories under the processing output root.
- Maps: use EvtxECmd maps bundled with the tool distribution, and support the helper script's sync mode for map updates before case processing.
- Manifest: record EvtxECmd version output, executable path, maps path when configured, input path, output paths, exit code, and output file hashes.

Example future tool-registry entry:

```yaml
tools:
  EvtxECmd:
    status: supported
    upstream: https://github.com/EricZimmerman/evtx
    download: https://ericzimmerman.github.io/
    runner: dotnet-native
    executable_candidates:
      - ~/.artefactprocessor/eztools/net9/EvtxECmd/EvtxECmd
      - ~/.artefactprocessor/eztools/net9/EvtxECmd/EvtxECmd.dll
      - ~/.artefactprocessor/eztools/net9/EvtxECmd/EvtxECmd.exe
    artefacts:
      - "**/*.evtx"
    outputs:
      - csv
      - json
```

## Tool bootstrap instructions

The GitHub instruction set should tell users to stage Eric Zimmerman tools before execution. The bootstrap script supports two flows:

```bash
# Print guidance and exact commands only.
scripts/bootstrap-eztools-macos.sh --dest ~/.artefactprocessor/eztools

# Download published .NET tool zips via Get-ZimmermanTools.ps1.
scripts/bootstrap-eztools-macos.sh --download --dest ~/.artefactprocessor/eztools --net-version 9 --sync
```

The processor should later add a `tools discover` or `tools doctor` command that reads this destination, finds all Eric Zimmerman tools, and writes/validates registry entries. The discovery goal is broad coverage for all Eric Zimmerman tools, while parser implementation should proceed incrementally with EvtxECmd first.

## CLI design

```bash
artefactprocessor kape init --kape-files /path/to/KapeFiles
artefactprocessor kape update --preview
artefactprocessor kape validate --modules EZParserSuite --input ./case001/artefacts
artefactprocessor kape process --input ./case001/artefacts --modules Registry --out ./case001/processed
artefactprocessor kape process --input ./case001/artefacts --modules EZParserSuite --out ./case001/processed
artefactprocessor kape report --run ./case001/processed/manifest.json
artefactprocessor kape tools doctor
artefactprocessor kape tools discover --eztools-root ~/.artefactprocessor/eztools/net9
artefactprocessor kape evtx --input ./case001/artefacts/Windows/System32/winevt/Logs --out ./case001/processed/evtx
```

## gkape-style GUI plan

A future GUI should provide:

- KapeFiles checkout status and module update preview.
- Module searchable trees with descriptions, dependencies, and macOS compatibility status.
- Existing artefact directory picker.
- Output folder and case metadata form.
- Preflight compatibility report for native .NET Eric Zimmerman modules on macOS.
- Live parser progress.
- Manifest, logs, CSV/JSON output browser, and skip/error summary.

## Security and forensic-soundness requirements

- Never write to the input artefact directory.
- Do not mount, image, acquire, triage, or copy evidence as part of processing.
- Keep parser output separated from input artefacts.
- Hash parser outputs and include hashes in the manifest.
- Record all tool versions and exact command lines.
- Fail closed for ambiguous path substitutions or variables.
- Treat KAPE definitions as data, not shell scripts; commands must be tokenized and safely rendered by the runner.

## Milestones

### Milestone 1: module definition and planning foundation

- Add KapeFiles checkout configuration.
- Parse enough `.mkape` metadata to list modules.
- Implement module validation and dependency preview.
- Create the processing manifest schema.

### Milestone 2: parser runner MVP

- Add a tool registry for Eric Zimmerman tools, with entries planned for every tool and support status captured explicitly.
- Implement the native .NET runner adapter.
- Implement EvtxECmd processing for `.evtx` files before expanding to additional parsers.
- Capture parser outputs and skip unsupported modules cleanly.

### Milestone 3: KAPE module compatibility expansion

- Add compound module support.
- Add variable expansion coverage for module processing paths.
- Add update preview and module definition diffing.
- Add module compatibility metadata for all Eric Zimmerman tools, prioritizing the most common Windows artefacts after EvtxECmd.

### Milestone 4: reporting and repeatability

- Add richer processing reports from `manifest.json`.
- Add output hashing and parser result inventories.
- Add rerun support that can compare tool versions, module definitions, and output files between runs.

### Milestone 5: gkape-style processing interface

- Build the module selection UI.
- Add input artefact directory validation, preflight checks, and live parser progress.
- Add report browsing and export shortcuts.

## Explicit non-goals

- No target collection implementation.
- No evidence imaging or mounting implementation.
- No writing to original evidence or supplied artefact directories.
- No promise that every upstream KAPE module will run on macOS.

## Open questions

- Which Eric Zimmerman tools publish native .NET builds that run reliably on Apple Silicon without additional shims?
- Should the project vendor a pinned KapeFiles snapshot, download on first run, or require the user to provide a checkout?
- Which KAPE module variables and command features are required for the first supported parser set?
- What are the first ten high-value Windows artefact families to support for processing end-to-end?
- What licensing constraints apply to bundling third-party parser binaries with this project?
