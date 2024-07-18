# Production tools for SPINE

This repository contains code used to drive [SPINE](https://github.com/DeepLearnPhysics/spine) in a production setting. All the scripts are currently tailored for the [SLURM workload manager](https://en.wikipedia.org/wiki/Slurm_Workload_Manager) used at S3DF and NERSC.

## Installation
Nothing to install, the package relies on the usage of singularities to package the dependencies.

Clone this repository and you're good to go!

### Usage
First, source the environment using the configure script in the base directory:
```bash
source configure.sh
```
Make sure to edit the script with the appropriate paths to `lartpc_mlreco3d`, `OpT0Finder` and the singularity container, if needed.

Most basic usage is to use the `run.sh` script in the base folder as follows
```bash
bash run.sh --config CONFIG_FILE --ntasks NTASKS [--flashmatch] file_list.txt
```
with
- `CONFIG_FILE`: Path to the configuration file of choice under the `config` fodler
- `NTASKS`: The number of processes to assign to the job. If not specified, only runs a single job

Only add the `--flashmatch` flag if you're running an analysis configuration and you want to use OpT0Finder (external package) to perform flashmatching.

The `file_list.txt` contains a list of paths to files to be processed. it can be produced very easily as follows:
```bash
ls -1 /path/to/dir/file*.ext > file_list.txt
```
One can also provide the file path directly at the end of the command line.

## Repository Structure
* `slurm` contains all slurm scripts related to production
* `config` contains experiment-specific configuration files

Please consult the `README` of each folder respectively for more information.
