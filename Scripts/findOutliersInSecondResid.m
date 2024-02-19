% This script is part of the GoldDigger workflow (step 6')
% This is the second outlier removal

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

%% Load the residual_model file as a numeric matrix
filename = 'TS_001/residual_model_or.resid';
startRow = 2;
formatSpec = '%10f%10f%5f%8f%f%[^\n\r]';
fileID = fopen(filename,'r');
dataArray = textscan(fileID, formatSpec, 'Delimiter', '', 'WhiteSpace', '', 'TextType', 'string', 'EmptyValue', NaN, 'HeaderLines' ,startRow-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');
fclose(fileID);
residualmodel = [dataArray{1:end-1}];
clearvars filename startRow formatSpec fileID dataArray ans;

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
fiducialFile = ones(10000,numberOfTilts,5);
% Put everything to -1 (because of the way processing is done later on)
fiducialFile = -1*fiducialFile;

for kk = 1 : size(residualmodel,1)-1
    
    % If the image number is greater than the previous one, then it might
    % be the same beads that we are tracking
    if residualmodel(kk,3) < residualmodel(kk+1,3)
        
        fiducialFile(fiducialNumber,residualmodel(kk,3)+1,1) = residualmodel(kk,1);
        fiducialFile(fiducialNumber,residualmodel(kk,3)+1,2) = residualmodel(kk,2);
        fiducialFile(fiducialNumber,residualmodel(kk,3)+1,3) = residualmodel(kk,3);
        fiducialFile(fiducialNumber,residualmodel(kk,3)+1,4) = residualmodel(kk,4);
        fiducialFile(fiducialNumber,residualmodel(kk,3)+1,5) = residualmodel(kk,5);
        
    else
        
        fiducialFile(fiducialNumber,residualmodel(kk,3)+1,1) = residualmodel(kk,1);
        fiducialFile(fiducialNumber,residualmodel(kk,3)+1,2) = residualmodel(kk,2);
        fiducialFile(fiducialNumber,residualmodel(kk,3)+1,3) = residualmodel(kk,3);        
        fiducialFile(fiducialNumber,residualmodel(kk,3)+1,4) = residualmodel(kk,4);
        fiducialFile(fiducialNumber,residualmodel(kk,3)+1,5) = residualmodel(kk,5);
        
        fiducialNumber = fiducialNumber + 1;
        
    end
    
end

% Remove the columns that are useless
fiducialFile(fiducialNumber+1:end,:,:) = [];

%% Remove 0 values in the X and Y shifts column where there is a -1 in the angle column, corresponding to empty fields
for kk = 1 : fiducialNumber
    
    j = find(fiducialFile(kk,:,3) == -1);
    fiducialFile(kk,j',4) = NaN;
    fiducialFile(kk,j',5) = NaN;
    
end

% Backup the file
fiducialFileBis = fiducialFile;

%% Read the multi
opts = delimitedTextImportOptions("NumVariables", 1);
opts.DataLines = [1, Inf];
opts.Delimiter = ",";
opts.VariableNames = "VarName1";
opts.VariableTypes = "double";
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
multi = readtable("TS_001/multi2.txt", opts);
multi = table2array(multi);
clear opts

%% Trying to identify the outliers
% This is performed per tilt-angle
for i = 1 : numberOfTilts
    
    % Set the range
    minRangeX = nanmedian(fiducialFile(:,i,4)) - multi*nanstd(fiducialFile(:,i,4));
    maxRangeX = nanmedian(fiducialFile(:,i,4)) + multi*nanstd(fiducialFile(:,i,4));
    
    minRangeY = nanmedian(fiducialFile(:,i,5)) - multi*nanstd(fiducialFile(:,i,5));
    maxRangeY = nanmedian(fiducialFile(:,i,5)) + multi*nanstd(fiducialFile(:,i,5));
    
    % Go through each fiducial and check if it fits inside the range
    for kk = 1 : fiducialNumber
        
        % If outside of the X range
        if fiducialFile(kk,i,4) < minRangeX || fiducialFile(kk,i,4) > maxRangeX
            
            % If outside of the Y range
            if fiducialFile(kk,i,5) < minRangeY || fiducialFile(kk,i,5) > maxRangeY
                
                % Set the tilt angle to -1 so we can easily get rid of it after that
                fiducialFileBis(kk,i,3) = -1;
                
            end
            
        end
        
    end
    
end


%% Let's get rid of the fiducials outside the range defined above
for kk = 1 : numberOfTilts
    
    % Find the number of beads
    i = find(fiducialFile(:,kk,3) == -1);
    j = find(fiducialFileBis(:,kk,3) == -1);
    fiducialFileBis(j',kk,4) = NaN;
    fiducialFileBis(j',kk,5) = NaN;
    
    howManyFiducialRemoved(kk,1) = size(i,1);
    howManyFiducialRemoved(kk,2) = size(j,1);
    
end

%% Let's count how many time each fiducial is not present, if it is too low we can discard it
for kk = 1 : fiducialNumber
    
    count = 0;
    
    for ll = 1 : numberOfTilts
        
        if fiducialFileBis(kk,ll,3) == -1
            
            count = count + 1;
            
        end
        
    end
    
    % This is what we define as too low
    if count >= numberOfTilts/3
        
        kk;
        fiducialFileBis(kk,:,3) = -1;
        
    end
    
end

%% Let's now remove all empty fiducials and create the final fiducial file
innerCounter = 0;
for kk = 1 : fiducialNumber
    
    for ll = 1 : numberOfTilts
        
        if fiducialFileBis(kk,ll,3) >= 0
            
            innerCounter = innerCounter + 1;
            finalFiducialFile(innerCounter,1) = kk;
            finalFiducialFile(innerCounter,2) = fiducialFileBis(kk,ll,1);
            finalFiducialFile(innerCounter,3) = fiducialFileBis(kk,ll,2);
            finalFiducialFile(innerCounter,4) = fiducialFileBis(kk,ll,3);
            
        end
        
    end
    
end
   
%% Let's write the file
writematrix(single(finalFiducialFile),'TS_001/TS_001_secondOutliersRemoved.txt','Delimiter',' ');

