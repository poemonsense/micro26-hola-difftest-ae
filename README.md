# HOLA MICRO 2026 Artifact Evaluation

This repository reproduces Section 6.2 Figures 11-14 and Table 4 from the
submitted HOLA paper. All hardware experiments use the NutShell Verilator
simulator; no FPGA or Palladium access is required.

## Required commands

Run only these three commands, in order, to complete the evaluation.

### Command 1: Get the artifact

```bash
git clone --recursive https://github.com/poemonsense/micro26-hola-difftest-ae
cd micro26-hola-difftest-ae
```

### Command 2: Pull the environment

```bash
docker pull ghcr.io/openxiangshan/xs-env:ubuntu-24.04
```

### Command 3: Run the complete evaluation

```bash
docker run --rm --name hola-ae \
  -v "$PWD:/ae" -w /ae \
  ghcr.io/openxiangshan/xs-env:ubuntu-24.04 \
  bash -lc './run-all.sh'
```

## What the commands do

No additional action is required. Command 1 obtains the artifact and its pinned
submodules. Command 2 downloads the complete build and simulation environment.
Command 3 prepares dependencies, builds all emulators, runs the Linux workload,
and writes:

- `evaluation/figure11.txt`
- `evaluation/figure12.txt`
- `evaluation/figure13.txt`
- `evaluation/figure14.txt`
- `evaluation/figure14.pdf`
- `evaluation/table4.txt`

Figures 11-13 use the final hardware-counter values printed by the firmware.
Figure 14 uses periodic simulator-counter snapshots to generate its curves.

Resource estimates and expected results are in [ae.tex](ae.tex).
