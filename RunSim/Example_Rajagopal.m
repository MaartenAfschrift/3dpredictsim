%% Batch Run StepWidth

% Influence of the kinematic constraint on stepwidth
clear all; close all; clc;

%% Default settings

% settings for optimization
S.v_tgt     = 1.25;     % average speed
S.N         = 25;       % number of mesh intervals
S.NThreads  = 4;        % number of threads for parallel computing

% quasi random initial guess, pelvis y position
S.IG_PelvisY = 0.896;   % subject 1 poggensee

% Folder with default functions
S.subject            = 'Rajagopal2015';
 
% output folder
S.ResultsFolder     = 'Example_Rajagopal2015_Poly';

% select tendon stiffness of 20
S.CasadiFunc_Folders = 'Casadi_Rajagopal2015';
% S.CasadiFunc_Folders = 'Casadi_Rajagopal2015_LongKneeM';

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
S.savename      = 'NoExo_b001';

% symmetric or periodic motion
S.Symmetric = true;
S.Periodic = false;

% select model
S.Model.Rajagopal = true;
S.Model.Default = false;

% weight on lumbar joint activations in objective func
S.W.Lumbar = 10^5;

% lower bound on muscle activity
S.Bounds.ActLower = 0.01;

% run optimization
f_PredSim_Rajagopal(S);     % run the optimization
f_LoadSim_Rajagopal(S.ResultsFolder,S.savename);




