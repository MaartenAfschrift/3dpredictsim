
% Rajagopal model
disp('Rajagopal model:');
osimModel = fullfile(pwd,'Rajagopal2015.osim');
DispMusclesOsimModel(osimModel);

% gait2392 model
disp(' ');
disp('gait9223 model:');
gait23 = fullfile('C:\Users\u0088756\Documents\FWO\Software\ExoSim\SimExo_3D\3dpredictsim\OpenSimModel','subject1_Poggensee_scaled.osim');
DispMusclesOsimModel(gait23);
