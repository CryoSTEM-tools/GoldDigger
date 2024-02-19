#!/bin/bash


# References
#
#   created by ST 01/11/23
#
#   Buckley G., Ramm G. and Trépout S., 'GoldDigger and Checkers, computational developments in
#   cryo-scanning transmission electron tomography to improve the quality of reconstructed volumes'
#   Journal, volume (year), page-page.
#
#   Ramaciotti Centre for CryoEM
#   Monash University
#   15, Innovation Walk
#   Clayton 3168
#   Victoria (The Place To Be)
#   Australia
#   https://www.monash.edu/researchinfrastructure/cryo-em/our-team


# Define the directory where computation is performed
workingdir=/home/strepout/st67/Projects/TestWorkflow

# The computing folder should contain the GoldDigger.sh file and all related matlab files as well

# The computing directory must have a specific structure (subfolder)

# Got to the working directory
cd $workingdir

# Create a subfolder
DIR=TS_001
if [[ ! -d "$DIR" ]];
then
	mkdir "$DIR"
fi


# Dynamo path
dynamodir=/home/strepout/st67/Soft/dynamo


# Relion tomo robot path
r4trdir=/home/strepout/st67/relionn_tomo_robot


# If gold beads need to be detected then set the variable to 1
# If gold beads have already been detected and you just want to compute alignment on pre-existing gold beads then set it to 0
needToGetBeads=1


# These variables are to disable/enable (0/1) the final optional outlier detection
outlierSearch1=1
outlierSearch2=1


# These variables set the range at which outliers are kept/discarded
# The range is defined as variable*std
outlierMulti1=0.5
outlierMulti2=0.5

echo "$outlierMulti1" > "$workingdir/TS_001/multi1.txt"
echo "$outlierMulti2" > "$workingdir/TS_001/multi2.txt"

# If you have several tilt-series to align, enter the first and last tomo numbers, if there are gaps it does not matter as they will be skipped
# If you have just one tilt-series, input its value twice
tomoStart=62
tomoStop=62

# Initial gold bead size and increment
goldBeadOrig=10
increase=5

# Orientation of the tilt-axis (relative to Y axis)
tiltAxis=0

# Enter pixel size (in nm) of the data
# It is asssumed that all data have the same pixel size
pixelsizeinnm=2
pixelsizeinang=$(echo -e "scale=4; 10 * $pixelsizeinnm" | bc)

# Finally, load the required modules
module purge
module load imod/4.11.15
module load matlab


# Computing loop
for i in $(seq -f "%03g" $tomoStart $tomoStop)
do
	
	# Define directory containing the data
	DIR="/home/strepout/sa61_scratch/ForRevisionBiologicalImaging/Tomo${i}/"

	# If the folder does not exist then it is just skipped, so there can be some gaps in the collected data
	if [ -d "$DIR" ];
	then

		# Echo directory just to keep track of where we are during processing
		echo $DIR

		# Let's increment the size of the gold beads
		goldBead=$goldBeadOrig

		# Here we copy the data from the data folder to the computing folder
		# Copy the tilt-series to the processing folder
		if [ -e "$DIR/Tomo${i}.mrc" ];
		then
			cp "$DIR/Tomo${i}.mrc" "$workingdir/TS_001/TS_001.mrc"
		else
			cp "$DIR/Tomo${i}.st" "$workingdir/TS_001/TS_001.mrc"
		fi

		# Copy the angle file to the processing folder
		cp "$DIR/Tomo${i}.rawtlt" "$workingdir/TS_001/TS_001.rawtlt"

		# If checked tilt-series exist either in mrc or st format
		if [ -e "$DIR/Tomo${i}_checked.mrc" ] || [ -e "$DIR/Tomo${i}_checked.st" ];
		then

			# Copy the tilt-series to the processing folder
			if [ -e "$DIR/Tomo${i}_checked.mrc" ];
			then
				cp "$DIR/Tomo${i}_checked.mrc" "$workingdir/TS_001/TS_001.mrc"
			else
				cp "$DIR/Tomo${i}_checked.st" "$workingdir/TS_001/TS_001.mrc"
			fi

			# Copy the angle file to the processing folder
			cp "$DIR/Tomo${i}_checked.rawtlt" "$workingdir/TS_001/TS_001.rawtlt"

		fi

		# If checked & mod tilt-series exist either in mrc or st format
		if [ -e "$DIR/Tomo${i}_checked_mod.mrc" ] || [ -e "$DIR/Tomo${i}_checked_mod.st" ];
		then

			# Copy the tilt-series to the processing folder
			if [ -e "$DIR/Tomo${i}_checked_mod.mrc" ];
			then
				cp "$DIR/Tomo${i}_checked_mod.mrc" "$workingdir/TS_001/TS_001.mrc"
			else
				cp "$DIR/Tomo${i}_checked_mod.st" "$workingdir/TS_001/TS_001.mrc"
			fi

			# Copy the angle file to the processing folder
			cp "$DIR/Tomo${i}_checked.rawtlt" "$workingdir/TS_001/TS_001.rawtlt"

		fi

		# Read the header of the mrc file to get the number of tilts in the next part of the script
		header "$workingdir/TS_001/TS_001.mrc" > "$workingdir/TS_001/myHeader"	

		#####################
		# GoldDigger step 1 #
		#####################

		# If beads need to be detected
		if [ $needToGetBeads -eq 1 ];
		then

			if [ ! -e "$DIR/Tomo${i}_checked_mod.mrc" ];
			then
				# Apply a median filter to improve bead detection
				clip median -2d "$workingdir/TS_001/TS_001.mrc" "$workingdir/TS_001/TS_001.mrc"
			fi

			##########################
			## Gold beads detection ##
			##########################	

			# Here we start a loop of 10 iterations which is going to look for gold beads of different sizes
			for g in {1..10}
			do

				# Start the dynamo robot alignment in Matlab
				matlab -nodesktop -r "cd $dynamodir,run('dynamo_activate.m'),cd $r4trdir,run('robot_activate.m'),dautoalign4relion_goldigger('$workingdir',$pixelsizeinang,$goldBead,$tiltAxis,'fast'),exit" -logfile "$workingdir/TS_001/matlab_output_${g}.txt"
				
				echo ""
				echo " --- "
				echo "Gold beads detected"
				echo " --- "
				echo ""

				# Let's increment the size of the gold beads
				goldBead=$(echo "$goldBead + $increase" | bc -l)

				#####################
				# GoldDigger step 2 #
				#####################
				
				# Let's extract the position of the fiducial contours
				model2point "$workingdir/TS_001/TS_001.mod" "$DIR/search_${g}.txt"
				
				# Clear some data before the next loop
				rm -rf "$workingdir/TS_001.AWF"
				rm -rf "$workingdir/TS_001/TS_001.AWF"
				rm "$workingdir/TS_001/TS_001.mod"
		
			done

			# Clear the tilt-series from the computing folder
			rm "$workingdir/TS_001/TS_001.mrc"*

		fi

		#####################
		# GoldDigger step 3 #
		#####################		

		# Concatenate all search results into a single file
		cat "$DIR/search_"*.txt > "$DIR/GBpositionsMerged.txt"

		# Copy this new file to the processing directory
		cp "$DIR/GBpositionsMerged.txt" "$workingdir/TS_001/TS_001_merged.txt"

		# Extract the number of tilts from the header 
		awk '$1 == "Number"{print $9}' "$workingdir/TS_001/myHeader" > "$workingdir/TS_001/numberOfTilts"

		#####################
		# GoldDigger step 4 #
		#####################		

		# Merge duplicated gold beads (generating longer chains)
		matlab -nodesktop -r "cd $workingdir,run('mergeChains.m'),exit" -logfile "$workingdir/TS_001/matlab_output_mergeChains.txt"			

		# Transform the coordinate file into a proper Imod fiducial file
		point2model -circle 5 "$workingdir/TS_001/TS_001_duplicatesMerged.txt" "$workingdir/TS_001/TS_001_duplicatesMerged.fid"

		#####################
		# GoldDigger step 5 #
		#####################	

		# Run tiltalign
		tiltalign -ModelFile "$workingdir/TS_001/TS_001_duplicatesMerged.fid" -ImagesAreBinned 1 -OutputModelFile "$workingdir/TS_001/3d_fiducial_model.3dmod" -OutputResidualFile "$workingdir/TS_001/residual_model.resid" -OutputFidXYZFile "$workingdir/TS_001/fiducials.xyz" -OutputTiltFile "$workingdir/TS_001/TS_001.tlt" -OutputXAxisTiltFile "$workingdir/TS_001/xtiltfile.xtilt" -OutputTransformFile "$workingdir/TS_001/TS_001.xf" -OutputFilledInModel "$workingdir/TS_001/model_nogaps.fid" -RotationAngle $tiltAxis -TiltFile "$workingdir/TS_001/TS_001.rawtlt" -AngleOffset 0.0 -RotOption -1 -RotDefaultGrouping 5 -TiltOption 0 -TiltDefaultGrouping 5 -MagReferenceView 1 -MagOption 0 -MagDefaultGrouping 4 -XStretchOption 0 -SkewOption 0 -XStretchDefaultGrouping 7 -SkewDefaultGrouping 11 -BeamTiltOption 0 -XTiltOption 0 -XTiltDefaultGrouping 2000 -ResidualReportCriterion 2.5 -SurfacesToAnalyze 1 -MetroFactor 0.25 -MaximumCycles 5000 -KFactorScaling 1.0 -NoSeparateTiltGroups 1 -AxisZShift 0 -ShiftZFromOriginal 1 -TargetPatchSizeXandY 700,700 -MinSizeOrOverlapXandY 0.5,0.5 -MinFidsTotalAndEachSurface 8,3 -FixXYZCoordinates 0 -LocalOutputOptions 1,0,1 -LocalRotOption 3 -LocalRotDefaultGrouping 6 -LocalTiltOption 5 -LocalTiltDefaultGrouping 6 -LocalMagReferenceView 1 -LocalMagOption 3 -LocalMagDefaultGrouping 7 -LocalXStretchOption 0 -LocalXStretchDefaultGrouping 7 -LocalSkewOption 0 -LocalSkewDefaultGrouping 11 -RobustFitting

		# Copy the alignment result to the data folder
		cp "$workingdir/TS_001/TS_001_duplicatesMerged.txt" "$DIR/Tomo${i}_duplicatesMerged.txt"					
		cp "$workingdir/TS_001/TS_001_duplicatesMerged.fid" "$DIR/Tomo${i}_duplicatesMerged.fid"
		cp "$workingdir/TS_001/3d_fiducial_model.3dmod" "$DIR/3d_fiducial_model.3dmod"
		cp "$workingdir/TS_001/residual_model.resid" "$DIR/residual_model.resid"
		cp "$workingdir/TS_001/fiducials.xyz" "$DIR/fiducials.xyz"
		cp "$workingdir/TS_001/TS_001.tlt" "$DIR/Tomo${i}.tlt"
		cp "$workingdir/TS_001/xtiltfile.xtilt" "$DIR/xtiltfile.xtilt"
		cp "$workingdir/TS_001/TS_001.xf" "$DIR/Tomo${i}.xf"
		cp "$workingdir/TS_001/model_nogaps.fid" "$DIR/model_nogaps.fid"

		#####################
		# GoldDigger step 6 #
		#####################	
	
		# Generate the aligned tilt-series
		if [ -e "$DIR/Tomo${i}_checked.mrc" ];
		then
			# Using the .mrc
			newstack -xform "$DIR/Tomo${i}.xf" -input "$DIR/Tomo${i}_checked.mrc" -output "$DIR/Tomo${i}.ali"
		else
			# or the .st
			newstack -xform "$DIR/Tomo${i}.xf" -input "$DIR/Tomo${i}_checked.st" -output "$DIR/Tomo${i}.ali"
		fi

		# Transform the fiducial model to fit the aligned stack (otherwise it fits the unaligned stack)
		imodtrans -i "$DIR/Tomo${i}.ali" -2 "$DIR/Tomo${i}.xf" "$DIR/model_nogaps.fid" "$DIR/Tomo${i}_ali.fid"

		rm "$workingdir/TS_001/TS_001_duplicatesMerged.txt"
		rm "$workingdir/TS_001/TS_001_duplicatesMerged.fid"
		rm "$workingdir/TS_001/3d_fiducial_model.3dmod"
		#rm "$workingdir/TS_001/residual_model.resid"
		rm "$workingdir/TS_001/fiducials.xyz"
		rm "$workingdir/TS_001/TS_001.tlt"
		rm "$workingdir/TS_001/xtiltfile.xtilt"
		rm "$workingdir/TS_001/TS_001.xf"
		rm "$workingdir/TS_001/model_nogaps.fid"

		######################
		# GoldDigger step 6' #
		######################	

		#############################
		## Remove outliers 1st run ##
		#############################

		if [ $outlierSearch1 -eq 1 ];
		then				

			# Run first outlier search
			matlab -nodesktop -r "cd $workingdir,run('findOutliersInFirstResid.m'),exit" -logfile "$workingdir/TS_001/matlab_output_firstOutliers.txt"			

			# Transform the coordinate file into a proper Imod fiducial file
			point2model -circle 5 "$workingdir/TS_001/TS_001_outliersRemoved.txt" "$workingdir/TS_001/TS_001_outliersRemoved.fid"

			# Re-run tiltalign
			tiltalign -ModelFile "$workingdir/TS_001/TS_001_outliersRemoved.fid" -ImagesAreBinned 1 -OutputModelFile "$workingdir/TS_001/3d_fiducial_model_or.3dmod" -OutputResidualFile "$workingdir/TS_001/residual_model_or.resid" -OutputFidXYZFile "$workingdir/TS_001/fiducials_or.xyz" -OutputTiltFile "$workingdir/TS_001/TS_001_or.tlt" -OutputXAxisTiltFile "$workingdir/TS_001/xtiltfile_or.xtilt" -OutputTransformFile "$workingdir/TS_001/TS_001_or.xf" -OutputFilledInModel "$workingdir/TS_001/model_nogaps_or.fid" -RotationAngle $tiltAxis -TiltFile "$workingdir/TS_001/TS_001.rawtlt" -AngleOffset 0.0 -RotOption -1 -RotDefaultGrouping 5 -TiltOption 0 -TiltDefaultGrouping 5 -MagReferenceView 1 -MagOption 0 -MagDefaultGrouping 4 -XStretchOption 0 -SkewOption 0 -XStretchDefaultGrouping 7 -SkewDefaultGrouping 11 -BeamTiltOption 0 -XTiltOption 0 -XTiltDefaultGrouping 2000 -ResidualReportCriterion 2.5 -SurfacesToAnalyze 1 -MetroFactor 0.25 -MaximumCycles 5000 -KFactorScaling 1.0 -NoSeparateTiltGroups 1 -AxisZShift 0 -ShiftZFromOriginal 1 -TargetPatchSizeXandY 700,700 -MinSizeOrOverlapXandY 0.5,0.5 -MinFidsTotalAndEachSurface 8,3 -FixXYZCoordinates 0 -LocalOutputOptions 1,0,1 -LocalRotOption 3 -LocalRotDefaultGrouping 6 -LocalTiltOption 5 -LocalTiltDefaultGrouping 6 -LocalMagReferenceView 1 -LocalMagOption 3 -LocalMagDefaultGrouping 7 -LocalXStretchOption 0 -LocalXStretchDefaultGrouping 7 -LocalSkewOption 0 -LocalSkewDefaultGrouping 11 -RobustFitting

			cp "$workingdir/TS_001/TS_001_outliersRemoved.txt" "$DIR/Tomo${i}_outliersRemoved.txt"					
			cp "$workingdir/TS_001/TS_001_outliersRemoved.fid" "$DIR/Tomo${i}_outliersRemoved.fid"
			cp "$workingdir/TS_001/3d_fiducial_model_or.3dmod" "$DIR/3d_fiducial_model_or.3dmod"
			cp "$workingdir/TS_001/residual_model_or.resid" "$DIR/residual_model_or.resid"
			cp "$workingdir/TS_001/fiducials_or.xyz" "$DIR/fiducials_or.xyz"
			cp "$workingdir/TS_001/TS_001_or.tlt" "$DIR/Tomo${i}_or.tlt"
			cp "$workingdir/TS_001/xtiltfile_or.xtilt" "$DIR/xtiltfile_or.xtilt"
			cp "$workingdir/TS_001/TS_001_or.xf" "$DIR/Tomo${i}_or.xf"
			cp "$workingdir/TS_001/model_nogaps_or.fid" "$DIR/model_nogaps_or.fid"

			# Generate the aligned tilt-series
			if [ -e "$DIR/Tomo${i}_checked.mrc" ];
			then
				# Using the .mrc
				newstack -xform "$DIR/Tomo${i}_or.xf" -input "$DIR/Tomo${i}_checked.mrc" -output "$DIR/Tomo${i}_or.ali"
			else
				# or the .st
				newstack -xform "$DIR/Tomo${i}_or.xf" -input "$DIR/Tomo${i}_checked.st" -output "$DIR/Tomo${i}_or.ali"
			fi

			# Transform the fiducial model to fit the aligned stack (otherwise it fits the unaligned stack)
			imodtrans -i "$DIR/Tomo${i}_or.ali" -2 "$DIR/Tomo${i}_or.xf" "$DIR/model_nogaps_or.fid" "$DIR/Tomo${i}_ali_or.fid"
		

			rm "$workingdir/TS_001/residual_model.resid"

			rm "$workingdir/TS_001/TS_001_outliersRemoved.txt"
			rm "$workingdir/TS_001/TS_001_outliersRemoved.fid"
			rm "$workingdir/TS_001/3d_fiducial_model_or.3dmod"
			#rm "$workingdir/TS_001/residual_model_or.resid"
			rm "$workingdir/TS_001/fiducials_or.xyz"
			rm "$workingdir/TS_001/TS_001_or.tlt"
			rm "$workingdir/TS_001/xtiltfile_or.xtilt"
			rm "$workingdir/TS_001/TS_001_or.xf"
			rm "$workingdir/TS_001/model_nogaps_or.fid"

		fi

		#############################
		## Remove outliers 2nd run ##
		#############################				

		if [ $outlierSearch2 -eq 1 ];
		then	

			matlab -nodesktop -r "cd $workingdir,run('findOutliersInSecondResid.m'),exit" -logfile "$workingdir/TS_001/matlab_output_secondOutliers.txt"			

			point2model -circle 5 "$workingdir/TS_001/TS_001_secondOutliersRemoved.txt" "$workingdir/TS_001/TS_001_secondOutliersRemoved.fid"

			tiltalign -ModelFile "$workingdir/TS_001/TS_001_secondOutliersRemoved.fid" -ImagesAreBinned 1 -OutputModelFile "$workingdir/TS_001/3d_fiducial_model_or2.3dmod" -OutputResidualFile "$workingdir/TS_001/residual_model_or2.resid" -OutputFidXYZFile "$workingdir/TS_001/fiducials_or2.xyz" -OutputTiltFile "$workingdir/TS_001/TS_001_or2.tlt" -OutputXAxisTiltFile "$workingdir/TS_001/xtiltfile_or2.xtilt" -OutputTransformFile "$workingdir/TS_001/TS_001_or2.xf" -OutputFilledInModel "$workingdir/TS_001/model_nogaps_or2.fid" -RotationAngle $tiltAxis -TiltFile "$workingdir/TS_001/TS_001.rawtlt" -AngleOffset 0.0 -RotOption -1 -RotDefaultGrouping 5 -TiltOption 0 -TiltDefaultGrouping 5 -MagReferenceView 1 -MagOption 0 -MagDefaultGrouping 4 -XStretchOption 0 -SkewOption 0 -XStretchDefaultGrouping 7 -SkewDefaultGrouping 11 -BeamTiltOption 0 -XTiltOption 0 -XTiltDefaultGrouping 2000 -ResidualReportCriterion 2.5 -SurfacesToAnalyze 1 -MetroFactor 0.25 -MaximumCycles 5000 -KFactorScaling 1.0 -NoSeparateTiltGroups 1 -AxisZShift 0 -ShiftZFromOriginal 1 -TargetPatchSizeXandY 700,700 -MinSizeOrOverlapXandY 0.5,0.5 -MinFidsTotalAndEachSurface 8,3 -FixXYZCoordinates 0 -LocalOutputOptions 1,0,1 -LocalRotOption 3 -LocalRotDefaultGrouping 6 -LocalTiltOption 5 -LocalTiltDefaultGrouping 6 -LocalMagReferenceView 1 -LocalMagOption 3 -LocalMagDefaultGrouping 7 -LocalXStretchOption 0 -LocalXStretchDefaultGrouping 7 -LocalSkewOption 0 -LocalSkewDefaultGrouping 11 -RobustFitting

			cp "$workingdir/TS_001/TS_001_secondOutliersRemoved.txt" "$DIR/Tomo${i}_secondOutliersRemoved.txt"					
			cp "$workingdir/TS_001/TS_001_secondOutliersRemoved.fid" "$DIR/Tomo${i}_secondOutliersRemoved.fid"
			cp "$workingdir/TS_001/3d_fiducial_model_or2.3dmod" "$DIR/3d_fiducial_model_or2.3dmod"
			cp "$workingdir/TS_001/residual_model_or2.resid" "$DIR/residual_model_or2.resid"
			cp "$workingdir/TS_001/fiducials_or2.xyz" "$DIR/fiducials_or2.xyz"
			cp "$workingdir/TS_001/TS_001_or2.tlt" "$DIR/Tomo${i}_or2.tlt"
			cp "$workingdir/TS_001/xtiltfile_or2.xtilt" "$DIR/xtiltfile_or2.xtilt"
			cp "$workingdir/TS_001/TS_001_or2.xf" "$DIR/Tomo${i}_or2.xf"
			cp "$workingdir/TS_001/model_nogaps_or2.fid" "$DIR/model_nogaps_or2.fid"

			# Generate the aligned tilt-series
			if [ -e "$DIR/Tomo${i}_checked.mrc" ];
			then
				# Using the .mrc
				newstack -xform "$DIR/Tomo${i}_or2.xf" -input "$DIR/Tomo${i}_checked.mrc" -output "$DIR/Tomo${i}_or2.ali"
			else
				# or the .st
				newstack -xform "$DIR/Tomo${i}_or2.xf" -input "$DIR/Tomo${i}_checked.st" -output "$DIR/Tomo${i}_or2.ali"
			fi

			# Transform the fiducial model to fit the aligned stack (otherwise it fits the unaligned stack)
			imodtrans -i "$DIR/Tomo${i}_or2.ali" -2 "$DIR/Tomo${i}_or2.xf" "$DIR/model_nogaps_or2.fid" "$DIR/Tomo${i}_ali_or2.fid"
		
			
			rm "$workingdir/TS_001/residual_model_or.resid"

			rm "$workingdir/TS_001/TS_001_secondOutliersRemoved.txt"
			rm "$workingdir/TS_001/TS_001_secondOutliersRemoved.fid"
			rm "$workingdir/TS_001/3d_fiducial_model_or2.3dmod"
			rm "$workingdir/TS_001/residual_model_or2.resid"
			rm "$workingdir/TS_001/fiducials_or2.xyz"
			rm "$workingdir/TS_001/TS_001_or2.tlt"
			rm "$workingdir/TS_001/xtiltfile_or2.xtilt"
			rm "$workingdir/TS_001/TS_001_or2.xf"
			rm "$workingdir/TS_001/model_nogaps_or2.fid"

		fi
		
		rm "$workingdir/TS_001/TS_001.mrc"
		rm "$workingdir/TS_001/TS_001.rawtlt"
		rm "$workingdir/TS_001/myHeader"
		rm "$workingdir/TS_001/numberOfTilts"
		rm "$workingdir/TS_001/TS_001_merged.fid"
		rm "$workingdir/TS_001/TS_001_merged.txt"
		rm "$workingdir/TS_001/matlab_output"*

	fi

done

