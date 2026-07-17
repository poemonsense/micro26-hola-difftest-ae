# HOLA MICRO 2026 Artifact Evaluation

This repository reproduces Section 6.2 Figures 11-14 and Table 4 from the
submitted HOLA paper. All hardware experiments use the NutShell Verilator
simulator; no FPGA or Palladium access is required.

## Required commands

Docker Engine with Linux-container support is required. The image-build stage
installs OS packages as root inside a Docker build layer; the artifact workflow
itself runs as the host UID/GID and does not write root-owned files.

Run only these two commands, in order, to complete the evaluation.

### Command 1: Get the artifact

```bash
git clone --recursive https://github.com/poemonsense/micro26-hola-difftest-ae
cd micro26-hola-difftest-ae
```

### Command 2: Build and run the non-root evaluation

```bash
./run-all.sh
```

## What the commands do

No additional action is required. Command 1 obtains the artifact and its pinned
submodules. Command 2 runs `run-all.sh`, which prints two progress stages: it
first derives a local image from the OpenXiangShan environment and installs the
system dependencies, then launches `artifact-evaluation.sh` as a user matching
the host UID/GID. All generated files are therefore host-owned:

- `evaluation/figure11.md`
- `evaluation/figure12.md`
- `evaluation/figure13.md`
- `evaluation/figure14.md`
- `evaluation/figure14.pdf`
- `evaluation/table4.md`

Figures 11-13 use the final hardware-counter values printed by the firmware.
Figure 14 uses periodic simulator-counter snapshots to generate its curves.

Resource estimates and expected results are in [ae.tex](ae.tex).
