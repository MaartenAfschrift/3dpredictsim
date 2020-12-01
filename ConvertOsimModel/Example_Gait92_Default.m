
%% Function: prepareInfoNLP

%% Inputs:

% path information
MainPath = 'C:\Users\u0088756\Documents\FWO\Software\ExoSim\SimExo_3D\3dpredictsim';
% settings:
 % Folder to save the polynomials
S.PolyFolder = 's1_Poggensee';
% Modelpath
% S.ModelPath = fullfile(MainPath,'OpenSimModel','subject1_Poggensee_scaled_hinge.osim'); 
S.ModelPath = fullfile(MainPath,'OpenSimModel','subject1_Poggensee_scaled.osim'); 
% Folder with CasadiFunctions
S.CasadiFunc_Folders = 's1_Poggensee_testLarsb'; 
% model selection options: Rajagopal, Gait92
S.ModelName = 'Gait92';      

% specific settings for exporting casadi functions
SettingsCasFunc.kTendon_CalfM = 20;
SettingsCasFunc.kMTP = 1.5/(pi/180)/5;
SettingsCasFunc.dMTP = 0.5;


%% Create only the casadi functions
% create casadi functions for equations in optimiztion problem
CreateCasadiFunctions(MainPath, S.ModelName, S.ModelPath, S.CasadiFunc_Folders,...
    S.PolyFolder,SettingsCasFunc);
