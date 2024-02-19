% This script is part of the GoldDigger workflow (step 4)
% It takes as inputs the list of fiducials detected by R4TR and the tilt
% angles to output a single file where fiducials are merged

%% References
%
%   created by ST 01/11/23
%
%   Buckley G., Ramm G. and Trépout S., 'GoldDigger and Checkers, computational developments in
%   cryo-scanning transmission electron tomography to improve the quality of reconstructed volumes'
%   Journal, volume (year), page-page.
%
%   Ramaciotti Centre for CryoEM
%   Monash University
%   15, Innovation Walk
%   Clayton 3168
%   Victoria (The Place To Be)
%   Australia
%   https://www.monash.edu/researchinfrastructure/cryo-em/our-team




%% Code

clear

%% Load the TS_001_merged.txt fiducial coordinates file as a numeric matrix
% This file contains the fiducial positions as picked by the robot
filename = 'TS_001/TS_001_merged.txt';
formatSpec = '%12f%12f%f%[^\n\r]';
fileID = fopen(filename,'r');
dataArray = textscan(fileID, formatSpec, 'Delimiter', '', 'WhiteSpace', '', 'TextType', 'string', 'EmptyValue', NaN,  'ReturnOnError', false);
fclose(fileID);
TS001merged = [dataArray{1:end-1}];
clearvars filename formatSpec fileID dataArray ans;

%% Read the text file containing the tilt angles
opts = delimitedTextImportOptions("NumVariables", 1);
opts.DataLines = [1, Inf];
opts.Delimiter = ",";
opts.VariableNames = "VarName1";
opts.VariableTypes = "double";
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
numberOfTilts = readtable("TS_001/numberOfTilts", opts);
numberOfTilts = table2array(numberOfTilts);
clear opts

%% First, identify the fiducials one by one and split them in a new file

% Intitialise the number of fiducials
fiducialNumber = 1;
% Generate a new fiducial file filled with ones
fiducialFile = ones(10000,numberOfTilts,3);
% Put everything to -1 (because of the way processing is done later on)
fiducialFile = -1*fiducialFile;

% Loop through the fiducial file
for kk = 1 : size(TS001merged,1)-1
    
    % If the image number is greater than the previous one, then it might
    % be the same beads that we are tracking
    if TS001merged(kk,3) < TS001merged(kk+1,3)
        
        fiducialFile(fiducialNumber,TS001merged(kk,3)+1,1) = TS001merged(kk,1);
        fiducialFile(fiducialNumber,TS001merged(kk,3)+1,2) = TS001merged(kk,2);
        fiducialFile(fiducialNumber,TS001merged(kk,3)+1,3) = TS001merged(kk,3);
        
    else
        
        fiducialFile(fiducialNumber,TS001merged(kk,3)+1,1) = TS001merged(kk,1);
        fiducialFile(fiducialNumber,TS001merged(kk,3)+1,2) = TS001merged(kk,2);
        fiducialFile(fiducialNumber,TS001merged(kk,3)+1,3) = TS001merged(kk,3);
        
        fiducialNumber = fiducialNumber + 1;
        
    end
    
end

% Remove the columns that we no longer need
fiducialFile(fiducialNumber+1:end,:,:) = [];

%% This value is the threshold we use to determine if two beads are the same
% or not
threshold = 10;

% Now, let's compute the distance between all fiducials
counter = 0;
% This variable stores the distance between fiducials
distanceMap = zeros(fiducialNumber,fiducialNumber,2);
% This variable indicates which fiducials are equivalent
sameFiducials = zeros(fiducialNumber,fiducialNumber);
% Backup
fiducialFileBis = fiducialFile;

% This file contains the fiducial number and will be used to go through
% each fiducial
x = (1:fiducialNumber);

% New way of going through the fiducials, where they are ranked
for kk = 1 : fiducialNumber
    
    % Need to delete the current fiducialNumber to avoid computing it
    % multiple times
    x(abs(x)==kk) = [];
    
    % Going through the remaining fiducial numbers
    for ii = 1 : size(x,2)
        
        % Get the value
        jj = x(1,ii);
        
        % Go through all the tilts
        for ll = 1 : numberOfTilts
            
            % Here we skip the columns where the is a -1 because it is
            % empty
            if fiducialFile(kk,ll,3) >= 0 && fiducialFile(jj,ll,3) >= 0
                
                % Compute the distance between the kkth and jjth fiducials
                pouet = sqrt( (fiducialFile(kk,ll,1) - fiducialFile(jj,ll,1)) * (fiducialFile(kk,ll,1) - fiducialFile(jj,ll,1)) ...
                    + (fiducialFile(kk,ll,2) - fiducialFile(jj,ll,2)) * (fiducialFile(kk,ll,2) - fiducialFile(jj,ll,2)));
                distanceMap(kk,jj,1) = distanceMap(kk,jj,1) + pouet; % This one sums up the error
                distanceMap(kk,jj,2) = distanceMap(kk,jj,2) + 1; % This one sums up the number of times the error has been summed up
            end
            
        end
        
        % Increase counter
        counter = counter + 1;
        
        % Compute average distance between the kkth and the jjth fiducials
        newPouet(counter) = distanceMap(kk,jj,1) / distanceMap(kk,jj,2);
        
        % If below the threshold then it is the same fiducial
        if newPouet(counter) > 0 && newPouet(counter) < threshold
            % And we write it down
            sameFiducials(kk,jj) = kk;
            % And put -1 in the fiducial file to avoid further processing
            % of this fiducial
            fiducialFileBis(jj,:,:) = -1;
        end
        
    end
    
end

%% Now merge the fiducials (meaning compute the coordinate average of the fiducials
% which are equivalent)
for kk = 1 : fiducialNumber
    
    % In the previous loop we set all coordinates of a fiducial to -1 if
    % this fiducial was the same as another one, so we should skip these
    % fiducials
    if sum(sum(fiducialFileBis(kk,:,:))) >= 0
        
        % Now, let's find the gold beads which are the same as the one we are
        % working on
        indx = find(sameFiducials(kk,:)==kk);
        
        for ll = 1 : numberOfTilts
            
            % That's the temporary X and Y coordinates of the fiducial
            tempX = 0;
            tempY = 0;
            
            % That's the counter to know how many fiducial positions we average
            counter = 0;
            
            % Coordinates exist only if the 3rd dimension (i.e., the image
            % number) is not equal to -1
            if fiducialFile(kk,ll,3) >= 0
                
                % Add the coordinate values of the first bead
                tempX = tempX + fiducialFile(kk,ll,1);
                tempY = tempY + fiducialFile(kk,ll,2);
                counter = counter + 1;
                
            end
            
            % Go through the other beads
            for ii = 1 : size(indx,2)
                
                % Coordinates exist only if the 3rd dimension (i.e., the image
                % number) is not equal to -1
                if fiducialFile(indx(ii),ll,3) >= 0
                    
                    % Add the coordinate values of the other beads
                    tempX = tempX + fiducialFile(indx(ii),ll,1);
                    tempY = tempY + fiducialFile(indx(ii),ll,2);
                    counter = counter + 1;
                    
                end
                
            end
            
            % This avoid going through empty fiducials (if they exist)
            if tempX > 0
                
                % Compute the average coordinate
                fiducialFileBis(kk,ll,1) = tempX/counter;
                fiducialFileBis(kk,ll,2) = tempY/counter;
                fiducialFileBis(kk,ll,3) = ll-1;
                
            end
            
        end
        
    end
    
end

% Let's now remove all empty fiducials
counter = 0;
innerCounter = 0;
for kk = 1 : fiducialNumber
    
    % Coordinates exist only if the 3rd dimension (i.e., the image number) is not equal to -1
    if sum(sum(fiducialFileBis(kk,:,:))) >= 0
        
        counter = counter + 1;
        
        for ll = 1 : numberOfTilts
            
            if fiducialFileBis(kk,ll,3) >= 0
                
                innerCounter = innerCounter + 1;
                % No pre-allocation of the file
                finalFiducialFile(innerCounter,1) = counter;
                finalFiducialFile(innerCounter,2) = fiducialFileBis(kk,ll,1);
                finalFiducialFile(innerCounter,3) = fiducialFileBis(kk,ll,2);
                finalFiducialFile(innerCounter,4) = fiducialFileBis(kk,ll,3);
                
            end
            
        end
        
    end
    
end

% Backup the final fiducial file
finalFiducialFileBis = finalFiducialFile;

% If more than 100 bead exist, we remove some of them
if counter > 100
    
    % Based on the chain length
    chainLength = zeros(counter,2);
    
    % Computation of the chain length
    for kk = 1 : size(chainLength,1)
        
        [i,j] = find(finalFiducialFileBis(:,1) == kk);
        
        chainLength(kk,1) = size(i,1);
        chainLength(kk,2) = kk;
        
    end
    
    % We sort the different lengths
    chainLengthSorted = sortrows(chainLength,'ascend');
    
    % Go through the X number of fiducial we need to discard
    numberOfBeadsToRemove = counter - 100;
    for kk = 1 : numberOfBeadsToRemove
        
        % Get the bead number
        beadNumber = chainLengthSorted(kk,2);
        
        % Find it
        [i,j] = find(finalFiducialFileBis(:,1) == beadNumber);
        
        % Put its coordinates to zero
        finalFiducialFileBis(i,:) = 0;
        
    end
    
    % Go back to the fiducial file from end to start
    for kk = size(finalFiducialFileBis,1) : -1 : 1
        
        % If the coordinates are 0
        if finalFiducialFileBis(kk,1) == 0
            
            % Clear the data
            finalFiducialFileBis(kk,:) = [];
            
        end
        
    end
        
end

% Write the text file
writematrix(single(finalFiducialFileBis),'TS_001/TS_001_duplicatesMerged.txt','Delimiter',' ');

