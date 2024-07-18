#!/bin/bash

# Check that the environement has been sourced
if [ -z ${MLPROD_BASEDIR+x} ]; then
	echo Must source configure.sh before running run.sh script
	exit 0
fi

# Define a helper function
help()
{
    echo "Usage: run.sh [-h]
              [-A | --account]
              [-a | --analysis]
	      [-f | --flashmatch]
              [-c | --config CONFIG]
	      [-n | --ntasks NUM_TASKS]
	      [-t | --time TIME]
	      [-s | --suffix SUFFIX]
	      FILES"
    exit 0
}

# Parse command-line optional arguments
ACCOUNT="neutrino:icarus-ml"
NUM_TASKS=1
ANALYSIS=false
FLASHMATCH=false
CONFIG=""
TIME="1:00:00"
SUFFIX=""
SHORT_OPTS="A:n:c:t:s:fah"
LONG_OPTS="account:,ntasks:,config:,time:,suffix:,flashmatch,analysis,help"
args=$(getopt -o $SHORT_OPTS -l $LONG_OPTS -- "$@")
eval set -- "$args"

while [ $# -ge 1 ]; do
        case "$1" in
                --)
			# File list at the end
			shift
                        break
			;;
		-A|--account)
			# Account name
			ACCOUNT=$2
			shift 2
			;;
		-a|--analysis)
			# Analysis mode
			ANALYSIS=true
			shift
			;;
		-f|--flashmatch)
			# Flashmatch enable
			FLASHMATCH=true
			shift
			;;
		-c|--config)
			# Configuration file
			CONFIG=$2
			shift 2
			;;
                -n|--ntasks)
			# Number of tasks to spawn
                        NUM_TASKS=$2
			shift 2
			;;
                -t|--time)
			# Time per process (not per batch!)
                        TIME=$2
			shift 2
			;;
                -s|--suffix)
			# Suffix to append to the input files names
                        SUFFIX=$2
			shift 2
			;;
                -h|--help)
			# Print help string
			help
                        ;;
        esac
done

# Determine which process to call
if $ANALYSIS; then
	PROCESS="ana"
else
	PROCESS="mlreco"
fi

# Parse the suffix
if [[ $SUFFIX == "" ]]; then
	SUFFIX=$PROCESS
fi

# Check a config was passed
if [[ $CONFIG == "" ]]; then
	echo Must specify a configuration file
	exit 0
fi

# Parse the input file list
if [[ -f $@ ]]; then
	# Get file extension
	FILENAME=$(basename -- $@)
	EXTENSION="${FILENAME##*.}"
	if [ $EXTENSION == 'txt' ]; then
	        # If the file is a txt file, assume it contains a file list
		FILE_LIST=$(cat $@)
	elif [ $EXTENSION == 'root' ] || [ $EXTENSION == 'h5' ]; then
		# If the file is a root or h5 file, assume it's an input file
		FILE_LIST=$@
	else
		# If the file is neither txt, root nor h5, throw
		echo File extension must be one of `root`, `h5` or `txt`
		exit 0
	fi
else
	# If the string is not a single path, assume it's a list
	FILE_LIST=$@
fi

FILES=($FILE_LIST)
NUM_FILES=${#FILES[@]}
if [[ $NUM_FILES -gt 0 ]]; then
	echo Found $NUM_FILES files to process
else
	echo No input file specified/found, abort
	exit 0
fi

# Check that the files in the list exist
for f in $FILE_LIST; do
	if [[ ! -f $f ]]; then
		echo $f not found, abort
	fi
done

# If the number of input files exeed the maximum submission array for Slurm,
# must make multiple submissions. Check there's enough processes available
MAX_ARRAY_SIZE=90
NUM_SUBS=$(($NUM_FILES/$MAX_ARRAY_SIZE + 1))
if [[ $NUM_SUBS -gt $NUM_TASKS ]]; then
	echo Must have at least as many processes as submissions
	echo Cannot launch $NUM_SUBS submissions on $NUM_TASKS processes
	exit 0
fi

# Parse the number of tasks (processes) to spawn. If the number of processes
# is smaller than the number of files, they will be queued.
if [[ $NUM_TASKS -gt $NUM_FILES ]]; then
	# If there are more processes than files, lower number of processes
	NUM_TASKS=$NUM_FILES
elif [[ $NUM_TASKS -lt 1 ]]; then
	# If the number of tasks is -1, spawn as many tasks as there are files 
	NUM_TASKS=$NUM_FILES
fi
echo Will spawn $NUM_TASKS job\(s\) in $NUM_SUBS submission\(s\)

# Launch submissions
LAST_ID=0
DATETIME=$(date +"%Y%m%d_%H%M%S_%N")
for SUB in $(seq $NUM_SUBS); do

	# Figure out how many tasks to assign to this submission
	SUB_NUM_TASKS=$(($NUM_TASKS/$NUM_SUBS))
	if [[ $(($NUM_TASKS%$NUM_SUBS)) -gt $(($SUB-1)) ]]; then
		SUB_NUM_TASKS=$(($SUB_NUM_TASKS + 1))
	fi

	# Figure out the IDs of the files to process in this batch
	FIRST_ID=$LAST_ID
	LAST_ID=$(($FIRST_ID+$SUB_NUM_TASKS*($NUM_FILES/$NUM_TASKS)))
	LEFTOVER=$(($NUM_FILES%$NUM_TASKS))
	if [[ $LEFTOVER -ge $NUM_SUBS ]]; then
		LAST_ID=$(($LAST_ID + $LEFTOVER/$NUM_SUBS))
	fi
	if [[ $(($LEFTOVER%$NUM_SUBS)) -gt $(($SUB-1)) ]]; then
		LAST_ID=$(($LAST_ID + 1))
	fi

	SUB_NUM_FILES=$((LAST_ID-FIRST_ID))

	# Build a table that maps the SLURM_ARRAY_TASK_ID to a file
	MAP_PATH="file_map_prod_${SUFFIX}_${DATETIME}_${SUB}.txt"
	CNTR=1

	echo "ArrayTaskID FilePath" > $MAP_PATH
	for FILE_ID in $(seq $FIRST_ID $(($LAST_ID-1))); do
      	        echo $CNTR ${FILES[FILE_ID]} >> $MAP_PATH
		CNTR=$((CNTR+1))
	done

	# Define the base command to execute
	BASE_COMMAND="singularity exec --bind /sdf/,/fs/ --nv $SINGULARITY_PATH bash -c \""

	# If a LArCV path is provided, source the environment in the singularity
	if [ $LARCV_BASEDIR ]; then
		BASE_COMMAND="${BASE_COMMAND}source $LARCV_BASEDIR/configure.sh; "
	fi

	# If flash-matching is requested, source the environment in the singularity
	if $FLASHMATCH; then
		BASE_COMMAND="${BASE_COMMAND}source $FMATCH_BASEDIR/configure.sh; "
	fi

	# Finalize the base command with the appropriate executable
	BASE_COMMAND="${BASE_COMMAND}python3 $SPINE_BASEDIR/bin/run.py"

	# Define a base sbatch script to bild from
	SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
      	BASE_SCRIPT=$SCRIPT_DIR/slurm/s3df_sbatch_${PROCESS}.sh

	# Construct submission script
	SCRIPT_PATH="submit_prod_${SUFFIX}_${DATETIME}_${SUB}.sh"

	mkdir -p output_$SUFFIX
	OUT_PATH="output_$SUFFIX/\${filename}_${SUFFIX}.h5"

	mkdir -p batch_logs
	LOG_PREFIX="batch_logs/prod_${SUFFIX}_%A_%a"

	echo "$(cat $BASE_SCRIPT)" > $SCRIPT_PATH
	echo "#SBATCH --time=$TIME" >> $SCRIPT_PATH
	echo "#SBATCH --account=$ACCOUNT" >> $SCRIPT_PATH
	echo "" >> $SCRIPT_PATH

	echo "#SBATCH --array=1-$SUB_NUM_FILES%$SUB_NUM_TASKS" >> $SCRIPT_PATH
	echo "" >> $SCRIPT_PATH

	echo "#SBATCH --job-name=prod_$SUFFIX" >> $SCRIPT_PATH
	echo "#SBATCH --output=$LOG_PREFIX.out" >> $SCRIPT_PATH
	echo "#SBATCH --error=$LOG_PREFIX.err" >> $SCRIPT_PATH
	echo "" >> $SCRIPT_PATH

	echo "map=$MAP_PATH" >> $SCRIPT_PATH
	echo "" >> $SCRIPT_PATH

	echo "file=\$(awk -v ArrayTaskID=\$SLURM_ARRAY_TASK_ID '\$1==ArrayTaskID {print \$2}' \$map)" >> $SCRIPT_PATH
	echo "filename=\$(basename -- \"\$file\")" >> $SCRIPT_PATH
	echo "filename=\"\${filename%.*}\"" >> $SCRIPT_PATH
	echo "" >> $SCRIPT_PATH

	echo "$BASE_COMMAND -s \$file -o $OUT_PATH -c $CONFIG\"" >> $SCRIPT_PATH

	# Execute
	sbatch $SCRIPT_PATH
done

# Done
exit 0
