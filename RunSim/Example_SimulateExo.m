%% Batch Run StepWidth

% Influence of the kinematic constraint on stepwidth
clear all; close all; clc;
addpath(genpath('C:\Users\u0088756\Documents\FWO\Software\ExoSim\SimExo_3D\3dpredictsim'));

%% Default settings

% settings for optimization
S.v_tgt     = 1.25;     % average speed
S.N         = 50;       % number of mesh intervals
S.NThreads  = 2;        % number of threads for parallel computing

% quasi random initial guess, pelvis y position
S.IG_PelvisY = 0.896;   % subject 1 poggensee

% Folder with default functions
S.subject            = 's1_Poggensee';

% output folder
S.ResultsFolder     = 'Example_ExoSimulation';

% select tendon stiffness of 20
S.CasadiFunc_Folders = 'Casadi_s1Pog_mtp';

% initial guess based on simulations without exoskeletons
S.IGsel         = 2;        % initial guess identifier (1: quasi random, 2: data-based)
S.IGmodeID      = 4;        % initial guess mode identifier (1 walk, 2 run, 3 prev.solution, 4 solution from /IG/Data folder)
S.savename_ig   = 'NoExo';  % name of the IG (.mot) file

% dataset with exoskeleton torque profile
S.DataSet       = 'PoggenSee2020_AFO';

% Simulation without exoskeelton
S.ExoBool       = 0;    
S.ExoScale      = 0;        % scale factor of exoskeleton assistance profile = 0 (i.e. no assistance)
S.ExternalFunc  = 'PredSim_3D_Pog_s1_mtp.dll';        % external function
S.ExternalFunc2 = 'PredSim_3D_Pog_s1_mtp_pp.dll';     % external function for post-processing
S.savename      = 'NoExo';
f_PredSim_PoggenSee2020(S);     % run the optimization
f_LoadSim_PoggenSee2020_DefaultS(S.ResultsFolder,S.savename) % post-proces simulation results


% Simulation with passive exoskeleton
S.ExoBool       = 1;    
S.ExoScale      = 0;        % scale factor of exoskeleton assistance profile = 0 (i.e. no assistance)
S.ExternalFunc  = 'SimExo_3D_talus_out.dll';        % external function
S.ExternalFunc2 = 'SimExo_3D_ExportAll.dll';        % external function for post-processing
S.savename      = 'Passive';
f_PredSim_PoggenSee2020(S);     % run the optimization
f_LoadSim_PoggenSee2020_DefaultS(S.ResultsFolder,S.savename) % post-proces simulation results

% Simulation with active exoskeleton
S.ExoBool       = 1;    
S.ExoScale      = 1;    
S.savename      = 'Active';
S.ExternalFunc  = 'SimExo_3D_talus_out.dll';        % external function
S.ExternalFunc2 = 'SimExo_3D_ExportAll.dll';        % external function for post processing
f_PredSim_PoggenSee2020(S);     % run the optimization
f_LoadSim_PoggenSee2020_DefaultS(S.ResultsFolder,S.savename) % post-proces simulation results

% (Katie Poggensee is doing the experiments with the exoskeleton emulator system)