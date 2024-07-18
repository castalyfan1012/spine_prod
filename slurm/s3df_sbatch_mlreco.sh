#!/bin/bash 

#SBATCH --partition=ampere

#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem-per-cpu=4g
#SBATCH --gpus=a100:1
