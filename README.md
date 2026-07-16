# HOLA MICRO 2026 Artifact Evaluation

This repository reproduces Section 6.2 Figures 11-14 and Table 4 from the
submitted HOLA paper. All hardware experiments use the NutShell Verilator
simulator; no FPGA or Palladium access is required.

## Command 1: Get the artifact

```bash
git clone --recursive https://github.com/poemonsense/micro26-hola-difftest-ae
cd micro26-hola-difftest-ae
```

## Command 2: Pull the environment

```bash
docker pull ghcr.io/openxiangshan/xs-env:ubuntu-24.04
```

## Command 3: Run the complete evaluation

```bash
docker run --rm --name hola-ae \
  -v "$PWD:/ae" -w /ae \
  ghcr.io/openxiangshan/xs-env:ubuntu-24.04 \
  bash -lc './run-all.sh'
```

No additional commands are required. Command 3 prepares dependencies, builds
all emulators, runs the Linux workload, and writes:

- `evaluation/figure11.txt`
- `evaluation/figure12.txt`
- `evaluation/figure13.txt`
- `evaluation/figure14.txt`
- `evaluation/figure14.pdf`
- `evaluation/table4.txt`

Resource estimates and expected results are in [ae.tex](ae.tex).
