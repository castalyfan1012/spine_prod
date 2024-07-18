#!/bin/bash 

#SBATCH --partition=turing

#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=4g
#SBATCH --gpus=geforce_rtx_2080_ti:1
