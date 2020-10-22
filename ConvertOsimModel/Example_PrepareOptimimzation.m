
%% Function: prepareInfoNLP

%% Inputs:

% path information
MainPath = 'C:\Users\u0088756\Documents\FWO\Software\ExoSim\SimExo_3D\3dpredictsim';

% settings:
 % Folder to save the polynomials
S.PolyFolder = 'testRajagopal';
% Modelpath
S.ModelPath = fullfile(MainPath,'OpenSimModel','Rajagopal2015.osim'); 
% Folder with CasadiFunctions
S.CasadiFunc_Folders = 'testRajagopal'; 
% path to Cpp file used in the optimization
S.CppFile_NLP = fullfile(MainPath,'ExternalFunctions','CppFiles','ID_Subject1.cpp'); 
 % path to Cpp file for post processing
S.CppFile_pp = fullfile(MainPath,'ExternalFunctions','CppFiles','Analyse_Subject1_pp.cpp');    
% Number of input arguments in the cpp file
S.CppFile_nInput = 93; 
% model selection options: Rajagopal, Gait92
S.ModelName = 'Rajagopal';      

% specific settings for exporting casadi functions
SettingsCasFunc.kTendon_CalfM = 20;
SettingsCasFunc.kMTP = 1.5/(pi/180)/5;
SettingsCasFunc.dMTP = 0.5;

% path information for automatically building cpp files
OsimSource  = 'C:\opensim-ad-core-source';
OsimBuild   = 'C:\opensim-ad-core-build2';
DllPath     = 'C:\Users\u0088756\Documents\FWO\Software\ExoSim\SimExo_3D\3dpredictsim\ExternalFunctions';
ExtFuncs    = 'C:\opensim-ExternalFunc';
VSinstall   = 'C:\Program Files (x86)\Microsoft Visual Studio 14.0';

%% 1: Polynomial fitting

% Fit polynmial functions
Bool_RunMA = 0; % Boolean to select if we have to run the muscle analysis
FitPolynomials(MainPath,S.ModelName,S.ModelPath,S.PolyFolder,Bool_RunMA)

%% 2: Create Casadifunctions

% create casadi functions for equations in optimiztion problem
CreateCasadiFunctions(MainPath, S.ModelName, S.ModelPath, S.CasadiFunc_Folders,...
    S.PolyFolder,SettingsCasFunc);

%% 3: Create .dll files if needed

% install the functions to create .dll files. you can download this matlab
% software here: https://github.com/MaartenAfschrift/CreateDll_PredSim
addpath('C:\Users\u0088756\Documents\FWO\Software\GitProjects\CreateDll_PredSim');

% create the .dll file automatically to solve the NLP
[CppDir,Name,~] = fileparts(S.CppFile_NLP);
CreateDllFileFromCpp(CppDir,Name,OsimSource,OsimBuild,DllPath,ExtFuncs,VSinstall,S.CppFile_nInput);

% create the .dll file automatically for postprocessing
[CppDir,Name,~] = fileparts(S.CppFile_pp);
CreateDllFileFromCpp(CppDir,Name,OsimSource,OsimBuild,DllPath,ExtFuncs,VSinstall,S.CppFile_nInput);
