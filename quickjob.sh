#!/bin/bash

#SBATCH --account=round-np
#SBATCH --partition=round-shared-np
#SBATCH -J qJ
#SBATCH -n 16
#SBATCH -t 11:00:00
#SBATCH -D /uufs/chpc.utah.edu/common/home/u0210816/
#SBATCH -o /uufs/chpc.utah.edu/common/home/u0210816/

module use ~/MyModules
module load miniconda3/latest

