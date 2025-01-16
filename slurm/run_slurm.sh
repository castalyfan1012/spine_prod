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
              [-p | --partition]
              [-G | --gpus]
              [--cpus-per-task]
              [--mem-per-cpu]
	      [--files-per-task]
              [-a | --analysis]
              [-f | --flashmatch]
	      [-d | --debug]
	      [-l | --larcv]
              [-c | --config CONFIG]
              [-n | --ntasks NUM_TASKS]
              [-t | --time TIME]
              [-s | --suffix SUFFIX]
              FILES"
    exit 0
}

# Parse command-line optional arguments
ACCOUNT="neutrino:icarus-ml"
PARTITION="turing"
GPUS=1
CPUS_PER_TASK=-1
FILES_PER_TASK=1
MEM_PER_CPU=""
NUM_TASKS=1
ANALYSIS=false
FLASHMATCH=false
DEBUG=false
LARCV_BASEDIR=""
CONFIG=""
TIME="1:00:00"
SUFFIX=""
SHORT_OPTS="A:p:G:n:c:t:s:l:fadh"
LONG_OPTS="account:,partition:,gpus:,cpus-per-task:,mem-per-cpu:,files-per-task:,ntasks:,config:,time:,suffix:,larcv:,flashmatch,analysis,debug,help"
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
                -p|--partition)
                        # Partition name
                        PARTITION=$2
                        shift 2
                        ;;
                -G|--gpus)
                        # GPU request
                        GPUS=$2
                        shift 2
                        ;;
                --cpus-per-task)
                        # Number of CPUs
                        CPUS_PER_TASK=$2
                        shift 2
                        ;;
                --mem-per-cpu)
                        # Memory per CPU
                        MEM_PER_CPU=$2
                        shift 2
                        ;;
                --files-per-task)
                        # Number of CPUs
                        FILES_PER_TASK=$2
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
                -d|--debug)
			# Debug mode enable (does not start the process)
                        DEBUG=true
                        shift
                        ;;
                -l|--larcv)
                        # Path to a custom LArCV
                        LARCV_BASEDIR=$2
                        shift 2
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

# If not explicitely specified, base the number of CPU cores
# and the memory assigned per CPU on the partition
if [[ $CPUS_PER_TASK -le 0 ]]; then
	if [[ $PARTITION == "ampere" ]]; then
		CPUS_PER_TASK=28
	elif [[ $PARTITION == "turing" ]]; then
		CPUS_PER_TASK=4
	fi
fi

if [[ $MEM_PER_CPU == "" ]]; then
	if [[ $PARTITION == "ampere" ]]; then
		MEM_PER_CPU="8g"
	elif [[ $PARTITION == "turing" ]]; then
		MEM_PER_CPU="4g"
	fi
fi

# Determine which process to call
if $ANALYSIS; then
        PROCESS="ana"
        GPUS=0
	PARTITION="milano"
	CPUS_PER_TASK=1
	MEM_PER_CPU="8g"
else
        PROCESS="spine"
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

# Define the number of files groups to build based on the number of files per
# task and redifine the number of files per task to optimize execution time
NUM_FILE_GROUPS=$((($NUM_FILES - 1)/$FILES_PER_TASK + 1))
FILES_PER_GROUP=()
for GROUP_ID in $(seq 0 $(($NUM_FILE_GROUPS - 1))); do
	NUM_GROUP_FILES=$(($NUM_FILES/$NUM_FILE_GROUPS))
	if [[ $(($NUM_FILES % $NUM_FILE_GROUPS)) -gt $GROUP_ID ]]; then
		NUM_GROUP_FILES=$(($NUM_GROUP_FILES + 1))
	fi
	FILES_PER_GROUP+=($NUM_GROUP_FILES)
done

# Parse the number of tasks (processes) to spawn. If the number of processes
# is smaller than the number of files, they will be queued.
if [[ $NUM_TASKS -gt $NUM_FILE_GROUPS ]]; then
        # If there are more processes than file groups, lower number of processes
        NUM_TASKS=$NUM_FILE_GROUPS
elif [[ $NUM_TASKS -lt 1 ]]; then
        # If the number of tasks is -1, spawn as many tasks as there are files 
        NUM_TASKS=$NUM_FILE_GROUPS
fi

# Figure out how many file groups to provide in each task
GROUPS_PER_TASK=()
for TASK_ID in $(seq 0 $(($NUM_TASKS - 1))); do
	NUM_GROUPS=$(($NUM_FILE_GROUPS/$NUM_TASKS))
	if [[ $(($NUM_FILE_GROUPS % $NUM_TASKS)) -gt $TASK_ID ]]; then
		NUM_GROUPS=$(($NUM_GROUPS + 1))
	fi
	GROUPS_PER_TASK+=($NUM_GROUPS)
done

# If the number of input file groups exeed the maximum submission array for Slurm,
# must make multiple submissions. Check there's enough processes available
MAX_ARRAY_SIZE=99
NUM_SUBS=$((($NUM_FILE_GROUPS - 1)/$MAX_ARRAY_SIZE + 1))
if [[ $NUM_SUBS -gt $NUM_TASKS ]]; then
        echo Must have at least as many processes as submissions
        echo Cannot launch $NUM_SUBS submissions on $NUM_TASKS processes
        exit 0
fi
echo Will process $NUM_FILES file\(s\) in $NUM_FILE_GROUPS job\(s\) using $NUM_TASKS parallel task\(s\) in $NUM_SUBS array\(s\) 

# Launch submissions
TASK_ID=0
GROUP_ID=0
FILE_ID=0
DATETIME=$(date +"%Y%m%d_%H%M%S_%N")
for SUB in $(seq $NUM_SUBS); do

        # Figure out how many tasks to assign to this submission
        SUB_NUM_TASKS=$(($NUM_TASKS/$NUM_SUBS))
        if [[ $(($NUM_TASKS%$NUM_SUBS)) -gt $(($SUB-1)) ]]; then
                SUB_NUM_TASKS=$(($SUB_NUM_TASKS + 1))
        fi

        # Build a table that maps the SLURM_ARRAY_TASK_ID to a file
        MAP_PATH="file_map_prod_${SUFFIX}_${DATETIME}_${SUB}.txt"
        CNTR=1

        echo "ArrayTaskID FilePath" > $MAP_PATH
	for TASK_ID in $(seq $TASK_ID $(($TASK_ID + $SUB_NUM_TASKS - 1))); do
		for GROUP_ID in $(seq $GROUP_ID $(($GROUP_ID + ${GROUPS_PER_TASK[$TASK_ID]} - 1))); do
			echo -n $CNTR" " >> $MAP_PATH
			for FILE_ID in $(seq $FILE_ID $(($FILE_ID + ${FILES_PER_GROUP[$GROUP_ID]} - 1))); do
				echo -n ${FILES[$FILE_ID]}, >> $MAP_PATH
			done
			echo "" >> $MAP_PATH # Carriage return
			FILE_ID=$((FILE_ID + 1))
			CNTR=$((CNTR+1))
		done
		GROUP_ID=$((GROUP_ID + 1))
	done

	TASK_ID=$(($TASK_ID + 1))

        # Define the base command to execute
        BASE_COMMAND="singularity exec --bind /sdf/,/fs/ --nv $SINGULARITY_PATH bash -c \""

        # If a LArCV path is provided, source the environment in the singularity
        if [ $LARCV_BASEDIR ]; then
                BASE_COMMAND="${BASE_COMMAND}unset which; source $LARCV_BASEDIR/configure.sh; "
        fi

        # If flash-matching is requested, source the environment in the singularity
        if $FLASHMATCH; then
                BASE_COMMAND="${BASE_COMMAND}source $FMATCH_BASEDIR/configure.sh; "
        fi

        # Finalize the base command with the appropriate executable
        BASE_COMMAND="${BASE_COMMAND}python3 $SPINE_BASEDIR/bin/run.py"

        # Define a base sbatch script to bild from
        SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

        # Construct submission script
        SCRIPT_PATH="submit_prod_${SUFFIX}_${DATETIME}_${SUB}.sh"

        mkdir -p batch_logs
        LOG_PREFIX="batch_logs/prod_${SUFFIX}_%A_%a"

        mkdir -p output_$SUFFIX
	OUTPUT_NAME="output_$SUFFIX/$SUFFIX.h5"

	echo "#!/bin/bash" >> $SCRIPT_PATH
	echo "" >> $SCRIPT_PATH
        echo "#SBATCH --account=$ACCOUNT" >> $SCRIPT_PATH
        echo "#SBATCH --partition=$PARTITION" >> $SCRIPT_PATH
	echo "" >> $SCRIPT_PATH
	echo "#SBATCH --ntasks=1" >> $SCRIPT_PATH
	echo "#SBATCH --cpus-per-task=$CPUS_PER_TASK" >> $SCRIPT_PATH
	echo "#SBATCH --mem-per-cpu=$MEM_PER_CPU" >> $SCRIPT_PATH
        echo "#SBATCH --time=$TIME" >> $SCRIPT_PATH
        echo "#SBATCH --gpus=$GPUS" >> $SCRIPT_PATH
        echo "" >> $SCRIPT_PATH

	echo "#SBATCH --array=1-$(($CNTR - 1))%$SUB_NUM_TASKS" >> $SCRIPT_PATH
        echo "" >> $SCRIPT_PATH

        echo "#SBATCH --job-name=prod_$SUFFIX" >> $SCRIPT_PATH
        echo "#SBATCH --output=$LOG_PREFIX.out" >> $SCRIPT_PATH
        echo "#SBATCH --error=$LOG_PREFIX.err" >> $SCRIPT_PATH
        echo "" >> $SCRIPT_PATH

        echo "map=$MAP_PATH" >> $SCRIPT_PATH
        echo "" >> $SCRIPT_PATH

        echo "file=\$(awk -v ArrayTaskID=\$SLURM_ARRAY_TASK_ID '\$1==ArrayTaskID {print \$2}' \$map)" >> $SCRIPT_PATH
	echo "file=\${file//,/\ }" >> $SCRIPT_PATH
        echo "" >> $SCRIPT_PATH

        echo "$BASE_COMMAND -s \$file -o $OUTPUT_NAME -c $CONFIG\"" >> $SCRIPT_PATH

        # Execute
        if ! $DEBUG; then
            sbatch $SCRIPT_PATH
	fi
done

# Done
exit 0
