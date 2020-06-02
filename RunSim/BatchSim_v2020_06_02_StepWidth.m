%% Batch Run StepWidth

% Influence of the kinematic constraint on stepwidth

clear all; close all; clc;

%% Default settings

% settings for optimization
S.v_tgt     = 1.25;     % average speed
S.N         = 50;       % number of mesh intervals
S.NThreads  = 4;        % number of threads for parallel computing

% quasi random initial guess, pelvis y position
S.IG_PelvisY = 0.896;   % subject 1 poggensee

% Folder with default functions
S.subject            = 's1_Poggensee';

% output folder
S.ResultsFolder     = 'Sens_StepWidth';

% select tendon stiffness of 20
S.CasadiFunc_Folders = 'Casadi_s1Pog_ScaleParam_k20';

% initial guess based on simulations without exoskeletons
S.IGsel         = 2;        % initial guess identifier (1: quasi random, 2: data-based)
S.IGmodeID      = 3;        % initial guess mode identifier (1 walk, 2 run, 3prev.solution)
S.ResultsF_ig   = 'BatchSim_2020_03_17_UpdIG';  % copied from 17_03_UpdIG
S.savename_ig   = 'NoExo';

%% Imposing change in stepwidth with passive exoskeleton

S.ExternalFunc  = 'SimExo_3D_talus_out.dll';        % this one is with the pinjoint mtp
S.ExoBool       = 1;
S.ExoScale      = 0;
S.DataSet       = 'PoggenSee2020_AFO';

Sens_dCalcn = 0.10:0.01:0.15;
nSim = length(Sens_dCalcn);

for i=1:nSim
    % set the kinematic constraint
    S.Constr.calcn = Sens_dCalcn(i);
    % Change the output name
    WidthStr = round(S.Constr.calcn*10);
    S.savename      = ['Passive_dCalcn_' num2str(WidthStr) 'cm'];
    % run the simulation
    f_PredSim_PoggenSee2020_CalcnT(S);
end

