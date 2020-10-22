%%%% Batch Run StepWidth

% Influence of the kinematic constraint on stepwidth
clear all; close all; clc;

%% Default settings

% settings for optimization
S.v_tgt     = 1.25;     % average speed
S.N         = 50;       % number of mesh intervals
S.NThreads  = 4;        % number of threads for parallel computing

% quasi random initial guess, pelvis y position
S.IG_PelvisY = 0.896;   % subject 1 poggensee

% Name of the subject
S.subject            = 'Rajagopal2015';
 
% output folder
S.ResultsFolder     = 'SimExo_Rajagopal';

% select folder with casadi equations
S.CasadiFunc_Folders = 'Casadi_Rajagopal2015';
% S.CasadiFunc_Folders = 'Casadi_Rajagopal2015_LongKneeM';

% select folder with polynomial functions
S.PolyFolder = 'Rajagopal2015';

% initial guess based on simulations without exoskeletons
S.IGsel         = 2;        % initial guess identifier (1: quasi random, 2: data-based)
S.IGmodeID      = 4;        % initial guess mode identifier (1 walk, 2 run, 3 prev.solution, 4 solution from /IG/Data folder)
S.savename_ig   = 'NoExo';  % name of the IG (.mot) file

% symmetric or periodic motion
S.Symmetric = true;
S.Periodic = false;

% select model
S.ModelName ={'Rajagopal'};

% weight on lumbar joint activations in objective func
S.W.Lumbar = 10^5;

% lower bound on muscle activity
S.Bounds.ActLower = 0.01;

%% Simulation without exoskeleton
S.ExoBool       = 0;    
S.ExoScale      = 0;        % scale factor of exoskeleton assistance profile = 0 (i.e. no assistance)
S.savename      = 'NoExo';
S.ExternalFunc  = 'PredSim_3D_Pog_s1_mtp.dll';        % external function
S.ExternalFunc2 = 'PredSim_3D_Pog_s1_mtp_pp.dll';     % external function for post-processing
f_PredSim_Rajagopal(S);     % run the optimization
f_LoadSim_Rajagopal(S.ResultsFolder,S.savename);

%% Simulation with passive exoskeleton
S.ExoBool       = 1;    
S.ExoScale      = 0;        % scale factor of exoskeleton assistance profile = 0 (i.e. no assistance)
S.savename      = 'Passive';
S.ExternalFunc  = 'SimExo_3D_talus_out.dll';        % external function
S.ExternalFunc2 = 'SimExo_3D_ExportAll.dll';        % external function for post-processing
S.DataSet       = 'PoggenSee2020_ExpPass';         % dataset exoskeleton assistance
f_PredSim_Rajagopal(S);     % run the optimization
f_LoadSim_Rajagopal(S.ResultsFolder,S.savename);

%% Simulation with active exoskeleton
S.ExoBool       = 1;    
S.ExoScale      = 1;        % scale factor of exoskeleton assistance profile = 0 (i.e. no assistance)
S.savename      = 'Active';
S.ExternalFunc  = 'SimExo_3D_talus_out.dll';        % external function
S.ExternalFunc2 = 'SimExo_3D_ExportAll.dll';        % external function for post-processing
S.DataSet       = 'PoggenSee2020_Exp';              % dataset exoskeleton assistance
f_PredSim_Rajagopal(S);     % run the optimization
f_LoadSim_Rajagopal(S.ResultsFolder,S.savename);