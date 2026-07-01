# ArtefactProcessor

ArtefactProcessor is planned as a macOS-native **processor** for already-acquired Windows forensic artefacts. It is not a collector: it does not image, mount, triage, acquire, or copy evidence from source media.

## Current focus

The first parser target is Windows Event Log processing with Eric Zimmerman's `EvtxECmd` using native .NET on macOS.

Design details live in [`docs/kape-gkape-macos-processor-plan.md`](docs/kape-gkape-macos-processor-plan.md).

## Eric Zimmerman tools setup

Users must stage Eric Zimmerman tools before running processing jobs. The project should support published tool zips from Eric Zimmerman's tool site and user-managed builds from cloned GitHub repositories.

Useful upstream links:

- Eric Zimmerman tools index: <https://ericzimmerman.github.io/>
- Get-ZimmermanTools helper: <https://github.com/EricZimmerman/Get-ZimmermanTools>
- EvtxECmd source repository: <https://github.com/EricZimmerman/evtx>

A guided bootstrap script is included:

```bash
# Print guidance only; no downloads.
scripts/bootstrap-eztools-macos.sh --dest ~/.artefactprocessor/eztools

# Download published native .NET tool builds via Get-ZimmermanTools.ps1.
scripts/bootstrap-eztools-macos.sh --download --dest ~/.artefactprocessor/eztools --net-version 9 --sync
```

The long-term registry goal is to model all Eric Zimmerman tools and mark each as `supported`, `planned`, or `unsupported-on-macos`. Implementation starts with EvtxECmd.
