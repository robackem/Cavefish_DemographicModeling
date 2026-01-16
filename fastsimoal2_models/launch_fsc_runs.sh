#!/bin/bash

# Originally from Laurent Excoffier February 2011
# Modified by Nina Marchi June 2020
# Modified by Emma Roback 2025 


fsc=fsc28
msgs=conOutput
mymail=robac028@umn.edu

# if doComputations==1, the script will submit runs of fsc to the HPC scheduler
# if doComputations==0, the script will just collect the results previously generated from past runs
# so uncomment the line you need

#doComputations=0
doComputations=1

#-------- Do computation or collect results ------
if [ $doComputations -eq 1 ]; then
	doCollectResults=0
else
	doCollectResults=1
fi

#-------- Number of different runs per data set ------
## Change this to do more or less iterations
numRuns=100
runBase=1
# jobcount=0
#-----------------------------

#SFStype="-m" ##minor allele freq
SFStype="-d" ##derived allele freq

mkdir $msgs 2>/dev/null

#-------- run values ------
iniNumSims=250000 ##-n 
#maxNumSims=200000
minNumLoopsInBrentOptimization=20 ##-l
maxNumLoopsInBrentOptimization=100 ##-L
minValidSFSEntry=1 ##-C
numCores=1 ##-c
numBatches=12 ##-B


#------ Use monomorphic sites or not---------
#useMonoSites="-0" #Uncomment this line NOT to use monomorphic sites
useMonoSites="" #Uncomment this line to use monomorphic sites

#-------- Estimate Ancestral State Misidentification ----------
#asm="--ASM"
asm=""
#----------multiSFS------------
# FYI you will never change this if you use Emma's SFS generation code
multiSFS=""
#multiSFS="--multiSFS"

#----------logprecision------------
#logprecision=""
logprecision="--logprecision 18"

#-----------------------------
quiet=""

# =========================
# discover model prefixes from *.tpl and validate .est exists
# =========================
shopt -s nullglob
prefixes=()
for tpl in ./*.tpl; do
	[ -e "$tpl" ] || continue
	base="${tpl##*/}"
	prefix="${base%.tpl}"
	if [ ! -f "${prefix}.est" ]; then
		echo "ERROR: Found ${tpl} but missing required ${prefix}.est. Aborting." >&2
		exit 1
	fi
	prefixes+=("$prefix")
done

if [ ${#prefixes[@]} -eq 0 ]; then
	echo "ERROR: No *.tpl files found in $(pwd). Nothing to do." >&2
	exit 1
fi

#-----------------------------
#dircount=0
#for case in Model1 Model2
#do
#	let dircount=dircount+1
#	for pop in Scenario1
#	do
#		job_description="${case}" #extract 3 first characters of pop
#		echo "job_description=$job_description" #debug
#
#		#-------- Generic Name ------
#		fileDirName=${pop}${case}
#		genericName=${pop}${case}
#		tplGenericName="${pop}${case}"
#
#		popDir="${pop}${case}"
#		mkdir $popDir 2>/dev/null
#		...
# The original loop above is replaced by a per-prefix loop
#-----------------------------

for prefix in "${prefixes[@]}"; do
	echo "Processing prefix: $prefix"
	fileDirName="${prefix}"
	genericName="${prefix}"
	tplGenericName="${prefix}"

	mkdir -p "$fileDirName" 2>/dev/null

	if [ $doComputations -eq 1 ]; then
		estFile=${tplGenericName}.est
		tplFile=${tplGenericName}.tpl

		for (( runsDone=$runBase; runsDone<=$numRuns; runsDone++ )); do
			runDir="run$runsDone"
			mkdir -p "$fileDirName/$runDir" 2>/dev/null
			echo "--------------------------------------------------------------------"
			echo ""
			echo "Current run: $runDir for $prefix"
			echo ""
			cd "$fileDirName/$runDir"

			#Copying necessary files (restricted to tpl|est|obs for this prefix)
			# (tpl/est are guaranteed present from earlier validation; obs may be multiple)
			# Use nullglob to avoid literal patterns when no matches
			shopt -s nullglob
			cp ../../"${prefix}.tpl" .
			cp ../../"${prefix}.est" .
			for f in ../../${prefix}*.obs; do
				[ -e "$f" ] && cp "$f" .
			done
			shopt -u nullglob

			jobName="${prefix}_${runsDone}.sh"

			#Creating bash file on the fly for each run
			(
			echo "#!/bin/bash"
			echo "#SBATCH --mail-user=${mymail}"
			echo "#SBATCH --ntasks=1"
			echo "#SBATCH --time=36:00:00"
			echo "#SBATCH --mem=1G"
			echo "#SBATCH --output=\"../../$msgs/${prefix}_$runsDone.out\""
			echo "#SBATCH --error=\"../../$msgs/${prefix}_$runsDone.err\""
			echo "#SBATCH --mail-type=none"
			echo "#SBATCH --cpus-per-task=12"
			echo ""
			echo ""
			echo "echo \"Analysis of file $genericName\""
			echo "#Computing likelihood of the parameters using the CM-Brent algorithm"
			echo "echo \"\""
	  		echo "$fsc -t ${genericName}.tpl -n$iniNumSims $SFStype -e ${genericName}.est -M -l$minNumLoopsInBrentOptimization -L$maxNumLoopsInBrentOptimization $quiet ${useMonoSites} -C${minValidSFSEntry} ${multiSFS} ${logprecision} -c${numCores} -B${numBatches} -y10 $asm"
			echo ""
			echo "echo \"\""
			echo "echo \"\""
			echo "echo \"Job $runsDone for $genericName terminated\""
			) > "$jobName"
			chmod +x "$jobName"

			echo "Bash file $jobName created"
			sbatch "./${jobName}"
			cd ../.. # leave $runDir back to scriptDir
		done
	fi

	if [ $doCollectResults -eq 1 ]; then
		# Collect bestlhoods across runs for this prefix
		outFile="${fileDirName}/${genericName}_bestLhoodsParams.txt"
		header_written=0

		for (( runsDone=$runBase; runsDone<=$numRuns; runsDone++ )); do
			runDir="run$runsDone"
			# Expected fsc output directory: <prefix>/runN/<prefix>/
			fscOutDir="${fileDirName}/${runDir}/${genericName}"
			bestlhoodFile="${fscOutDir}/${genericName}.bestlhoods"

			if [ ! -d "$fscOutDir" ] || [ ! -f "$bestlhoodFile" ]; then
				echo "WARNING: Missing results for ${genericName} ${runDir} (expected ${bestlhoodFile}). Skipping." >&2
				continue
			fi

			if [ $header_written -eq 0 ]; then
				header=$(sed -n '1p' "$bestlhoodFile")
				echo -e "Run\t$header" > "$outFile"
				header_written=1
			fi

			wantedParameters=$(sed -n '2p' "$bestlhoodFile")
			echo -e "run$runsDone\t$wantedParameters" >> "$outFile"
		done

		if [ $header_written -eq 1 ]; then
			echo "Extracted parameters summary -> $outFile"
		else
			echo "NOTE: No successful runs found to summarize for $genericName."
		fi
	fi
done
