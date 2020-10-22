% This function returns the muscle indices used in the optimization problem
% as compared to all muscles of the gait2392 model
%
% Author: Antoine Falisse
% Date: 12/19/2018
% 
function musi = MuscleIndices(muscleNames,muscleNames_all)
   
count = 1;
musi = zeros(1,length(muscleNames));
for i = 1:length(muscleNames)       
    if (find(strcmp(muscleNames_all,muscleNames{i})) ~= 0)        
        musi(count) = find(strcmp(muscleNames_all,muscleNames{i}));
        count = count + 1;
    end
end

end
