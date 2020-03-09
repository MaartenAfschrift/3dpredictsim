function [R] = f_LoadSim_PoggenSee2020_DefaultS(ResultsFolder,loadname)


%% Notes

% to simplify batch processing, the casadi functions were already created
% using the script CasadiFunctions_all_mtp_createDefault.m
% This assumes invariant:
%   Muscle and tendon properties
%   Polynomials to compute moment arms
%   Functions to compute passive stiffness

% We can still vary:
% 1) the collocation scheme
% 2) the weights in the objective function
% 3) the exoskeleton assistance
% 4) the external function
pathmain = pwd;
[pathRepo,~,~] = fileparts(pathmain);
OutFolder = fullfile(pathRepo,'Results',ResultsFolder);
Outname = fullfile(OutFolder,[loadname '.mat']);
load(Outname,'w_opt','stats','Sopt','ExoControl');
S = Sopt;

%% User inputs (typical settings structure)
% load default CasadiFunctions

% flow control
writeIKmotion   = 1; % set to 1 to write .mot file

% settings for optimization
v_tgt       = S.v_tgt;      % average speed
N           = S.N;          % number of mesh intervals
W.E         = S.W.E;        % weight metabolic energy rate
W.Ak        = S.W.Ak;       % weight joint accelerations
W.ArmE      = S.W.ArmE;     % weight arm excitations
W.passMom   = S.W.passMom;  % weight passive torques
W.A         = S.W.A;        % weight muscle activations
exp_E       = S.W.exp_E;    % power metabolic energy
W.Mtp       = S.W.Mtp;      % weight mtp excitations
W.u         = S.W.u;        % weight on exctiations arm actuators
IGsel       = S.IGsel;      % initial guess identifier
IGm         = S.IGmodeID;   % initial guess mode identifier
coCont      = S.coCont;     % co-contraction identifier

% identifier for EMG load
savename_ig = S.savename_ig;

% ipopt options
tol_ipopt       = S.tol_ipopt;

%% Settings

import casadi.*

if ~isfield(S,'subject') || isempty(S.subject)
    S.subject = 'subject1';
end
subject = S.subject;

%% Select settings

%% Load external functions
% The external function performs inverse dynamics through the
% OpenSim/Simbody C++ API. This external function is compiled as a dll from
% which we create a Function instance using CasADi in MATLAB. More details
% about the external function can be found in the documentation.
pathmain = pwd;
% We use different external functions, since we also want to access some
% parameters of the model in a post-processing phase.
[pathRepo,~,~] = fileparts(pathmain);
pathExternalFunctions = [pathRepo,'/ExternalFunctions'];
% Loading external functions.
cd(pathExternalFunctions);
F1 = external('F',S.ExternalFunc2);
cd(pathmain);


%% Indices external function
% Indices of the elements in the external functions
% External function: F
% First, joint torques.
jointi.pelvis.tilt  = 1;
jointi.pelvis.list  = 2;
jointi.pelvis.rot   = 3;
jointi.pelvis.tx    = 4;
jointi.pelvis.ty    = 5;
jointi.pelvis.tz    = 6;
jointi.hip_flex.l   = 7;
jointi.hip_add.l    = 8;
jointi.hip_rot.l    = 9;
jointi.hip_flex.r   = 10;
jointi.hip_add.r    = 11;
jointi.hip_rot.r    = 12;
jointi.knee.l       = 13;
jointi.knee.r       = 14;
jointi.ankle.l      = 15;
jointi.ankle.r      = 16;
jointi.subt.l       = 17;
jointi.subt.r       = 18;
jointi.mtp.l        = 19;
jointi.mtp.r        = 20;
jointi.trunk.ext    = 21;
jointi.trunk.ben    = 22;
jointi.trunk.rot    = 23;
jointi.sh_flex.l    = 24;
jointi.sh_add.l     = 25;
jointi.sh_rot.l     = 26;
jointi.sh_flex.r    = 27;
jointi.sh_add.r     = 28;
jointi.sh_rot.r     = 29;
jointi.elb.l        = 30;
jointi.elb.r        = 31;
% Vectors of indices for later use
residualsi          = jointi.pelvis.tilt:jointi.elb.r; % all
ground_pelvisi      = jointi.pelvis.tilt:jointi.pelvis.tz; % ground-pelvis
trunki              = jointi.trunk.ext:jointi.trunk.rot; % trunk
armsi               = jointi.sh_flex.l:jointi.elb.r; % arms
mtpi                = jointi.mtp.l:jointi.mtp.r; % mtps
residuals_noarmsi   = jointi.pelvis.tilt:jointi.trunk.rot; % all but arms
roti                = [jointi.pelvis.tilt:jointi.pelvis.rot,...
    jointi.hip_flex.l:jointi.elb.r];
% Number of degrees of freedom for later use
nq.all      = length(residualsi); % all
nq.abs      = length(ground_pelvisi); % ground-pelvis
nq.trunk    = length(trunki); % trunk
nq.arms     = length(armsi); % arms
nq.mtp     = length(mtpi); % arms
nq.leg      = 10; % #joints needed for polynomials
% Second, origins bodies.
% Calcaneus
calcOr.r    = 32:33;
calcOr.l    = 34:35;
calcOr.all  = [calcOr.r,calcOr.l];
NcalcOr     = length(calcOr.all);
% Femurs
femurOr.r   = 36:37;
femurOr.l   = 38:39;
femurOr.all = [femurOr.r,femurOr.l];
NfemurOr    = length(femurOr.all);
% Hands
handOr.r    = 40:41;
handOr.l    = 42:43;
handOr.all  = [handOr.r,handOr.l];
NhandOr     = length(handOr.all);
% Tibias
tibiaOr.r   = 44:45;
tibiaOr.l   = 46:47;
tibiaOr.all = [tibiaOr.r,tibiaOr.l];
NtibiaOr    = length(tibiaOr.all);
% External function: F1 (post-processing purpose only)
% Ground reaction forces (GRFs)
GRFi.r      = 32:34;
GRFi.l      = 35:37;
GRFi.all    = [GRFi.r,GRFi.l];
NGRF        = length(GRFi.all);
% Origins calcaneus (3D)
calcOrall.r     = 38:40;
calcOrall.l     = 41:43;
calcOrall.all   = [calcOrall.r,calcOrall.l];
NcalcOrall      = length(calcOrall.all);

%% Model info
body_weight = S.mass*9.81;

%% Collocation scheme
% We use a pseudospectral direct collocation method, i.e. we use Lagrange
% polynomials to approximate the state derivatives at the collocation
% points in each mesh interval. We use d=3 collocation points per mesh
% interval and Radau collocation points.
pathCollocationScheme = [pathRepo,'/CollocationScheme'];
addpath(genpath(pathCollocationScheme));
d = 3; % degree of interpolating polynomial
method = 'radau'; % collocation method
[tau_root,C,D,B] = CollocationScheme(d,method);

%% Muscle-tendon parameters
% Muscles from one leg and from the back
muscleNames = {'glut_med1_r','glut_med2_r','glut_med3_r',...
    'glut_min1_r','glut_min2_r','glut_min3_r','semimem_r',...
    'semiten_r','bifemlh_r','bifemsh_r','sar_r','add_long_r',...
    'add_brev_r','add_mag1_r','add_mag2_r','add_mag3_r','tfl_r',...
    'pect_r','grac_r','glut_max1_r','glut_max2_r','glut_max3_r',......
    'iliacus_r','psoas_r','quad_fem_r','gem_r','peri_r',...
    'rect_fem_r','vas_med_r','vas_int_r','vas_lat_r','med_gas_r',...
    'lat_gas_r','soleus_r','tib_post_r','flex_dig_r','flex_hal_r',...
    'tib_ant_r','per_brev_r','per_long_r','per_tert_r','ext_dig_r',...
    'ext_hal_r','ercspn_r','intobl_r','extobl_r','ercspn_l',...
    'intobl_l','extobl_l'};
% Muscle indices for later use
pathmusclemodel = [pathRepo,'/MuscleModel'];
addpath(genpath(pathmusclemodel));
% (1:end-3), since we do not want to count twice the back muscles
musi = MuscleIndices(muscleNames(1:end-3));
% Total number of muscles
NMuscle = length(muscleNames(1:end-3))*2;
% Muscle-tendon parameters. Row 1: maximal isometric forces; Row 2: optimal
% fiber lengths; Row 3: tendon slack lengths; Row 4: optimal pennation
% angles; Row 5: maximal contraction velocities
pathpolynomial = fullfile(pathRepo,'Polynomials',S.subject);
addpath(genpath(pathpolynomial));
tl = load([pathpolynomial,'/muscle_spanning_joint_INFO_',subject,'_mtp.mat']);
[~,mai] = MomentArmIndices(muscleNames(1:end-3),...
    tl.muscle_spanning_joint_INFO(1:end-3,:));

% Parameters for activation dynamics
tact = 0.015; % Activation time constant
tdeact = 0.06; % Deactivation time constant

%% Metabolic energy model parameters
% We extract the specific tensions and slow twitch rations.
pathMetabolicEnergy = [pathRepo,'/MetabolicEnergy'];
addpath(genpath(pathMetabolicEnergy));
% (1:end-3), since we do not want to count twice the back muscles
tension = getSpecificTensions(muscleNames(1:end-3));
tensions = [tension;tension];
% (1:end-3), since we do not want to count twice the back muscles
pctst = getSlowTwitchRatios(muscleNames(1:end-3));
pctsts = [pctst;pctst];

%% CasADi functions
% We create several CasADi functions for later use
pathCasADiFunctions = [pathRepo,'/CasADiFunctions'];
PathDefaultFunc = fullfile(pathCasADiFunctions,S.CasadiFunc_Folders);
cd(PathDefaultFunc);
% f_coll = Function.load('f_coll');
f_FiberLength_TendonForce_tendon = Function.load('f_FiberLength_TendonForce_tendon');
f_FiberVelocity_TendonForce_tendon = Function.load('f_FiberVelocity_TendonForce_tendon');
f_forceEquilibrium_FtildeState_all_tendon = Function.load('f_forceEquilibrium_FtildeState_all_tendon');
f_J2    = Function.load('f_J2');
f_J23   = Function.load('f_J23');
f_J25   = Function.load('f_J25');
f_J8    = Function.load('f_J8');
f_J92   = Function.load('f_J92');
f_J92exp = Function.load('f_J92exp');
f_Jnn3  = Function.load('f_Jnn3');
f_lMT_vMT_dM = Function.load('f_lMT_vMT_dM');
f_AllPassiveTorques = Function.load('f_AllPassiveTorques');
fgetMetabolicEnergySmooth2004all = Function.load('fgetMetabolicEnergySmooth2004all');
cd(pathmain);

%% Experimental data
% We extract experimental data to set bounds and initial guesses if needed
pathData = [pathRepo,'/OpenSimModel/',subject];
joints = {'pelvis_tilt','pelvis_list','pelvis_rotation','pelvis_tx',...
    'pelvis_ty','pelvis_tz','hip_flexion_l','hip_adduction_l',...
    'hip_rotation_l','hip_flexion_r','hip_adduction_r','hip_rotation_r',...
    'knee_angle_l','knee_angle_r','ankle_angle_l','ankle_angle_r',...
    'subtalar_angle_l','subtalar_angle_r','mtp_angle_l','mtp_angle_r',...
    'lumbar_extension','lumbar_bending','lumbar_rotation','arm_flex_l',...
    'arm_add_l','arm_rot_l','arm_flex_r','arm_add_r','arm_rot_r',...
    'elbow_flex_l','elbow_flex_r'};
pathVariousFunctions = [pathRepo,'/VariousFunctions'];
addpath(genpath(pathVariousFunctions));
% Extract joint positions from average walking motion
motion_walk         = 'walking';
nametrial_walk.id   = ['average_',motion_walk,'_HGC_mtp'];
nametrial_walk.IK   = ['IK_',nametrial_walk.id];
pathIK_walk         = [pathData,'/IK/',nametrial_walk.IK,'.mat'];
Qs_walk             = getIK(pathIK_walk,joints);

%% Bounds
pathBounds = [pathRepo,'/Bounds'];
addpath(genpath(pathBounds));
[bounds,scaling] = getBounds_all_mtp(Qs_walk,NMuscle,nq,jointi,v_tgt);
% Simulate co-contraction by increasing the lower bound on muscle activations
if coCont == 1
    bounds.a.lower = 0.1*ones(1,NMuscle);
elseif coCont == 2
    bounds.a.lower = 0.15*ones(1,NMuscle);
elseif coCont == 3
    bounds.a.lower = 0.2*ones(1,NMuscle);
end

%% exoskeleton torques
ExoControl = [];
body_mass = S.mass;
if S.ExoBool
    if strcmp(S.DataSet,'Zhang2017')
        % load the data from Zhang 2017
        [DataPath,~,~] = fileparts(pathRepo);
        Zhang = load([DataPath,'\Data\Zhang_2017\opt_tau.mat']);
        Tankle = nanmean(Zhang.opt_tau)*-1.*body_mass; % -1 because plantarflexion is negative in opensim model
        ExoSpline.Tankle = spline(linspace(0,2,length(Tankle)*2),[Tankle Tankle]);
    elseif strcmp(S.DataSet,'PoggenSee2020_AFO')
        [DataPath,~,~] = fileparts(pathRepo);
        Poggensee = load([DataPath,'\Data\Poggensee_2020\torque_profile.mat']);
        Tankle = Poggensee.torque*-1*body_mass; % -1 because plantarflexion is negative in opensim model
        ExoSpline.Tankle = spline(linspace(0,2,length(Tankle)*2),[Tankle' Tankle']);
    else
        error(['Could not find the dataset ' S.DataSet ' to prescribe the exoskeleton torques']);
    end
    
    ExoControl.Tankle_r = ppval(ExoSpline.Tankle,linspace(0,0.5,N));
    ExoControl.Tankle_l = ppval(ExoSpline.Tankle,linspace(0.5,1,N));
    if isfield(S,'ExoScale')
        ExoControl.Tankle_r = ExoControl.Tankle_r*S.ExoScale;
        ExoControl.Tankle_l = ExoControl.Tankle_l*S.ExoScale;
    end
    ExoVect = [ExoControl.Tankle_l; ExoControl.Tankle_r];
else
    ExoVect = zeros(2,N);
end

%% Index helpers

% indexes to select kinematics left and right leg
IndexLeft = [jointi.hip_flex.l jointi.hip_add.l jointi.hip_rot.l, ...
    jointi.knee.l jointi.ankle.l jointi.subt.l jointi.mtp.l,...
    jointi.trunk.ext, jointi.trunk.ben, jointi.trunk.rot];
IndexRight = [jointi.hip_flex.r jointi.hip_add.r jointi.hip_rot.r, ...
    jointi.knee.r jointi.ankle.r jointi.subt.r jointi.mtp.r,...
    jointi.trunk.ext, jointi.trunk.ben, jointi.trunk.rot];

% Helper variables to reconstruct full gait cycle assuming symmetry
QsSymA = [jointi.pelvis.tilt,jointi.pelvis.ty,...
    jointi.hip_flex.l:jointi.trunk.ext,...
    jointi.sh_flex.l:jointi.elb.r];
QsSymB = [jointi.pelvis.tilt,jointi.pelvis.ty,...
    jointi.hip_flex.r:jointi.hip_rot.r,...
    jointi.hip_flex.l:jointi.hip_rot.l,...
    jointi.knee.r,jointi.knee.l,...
    jointi.ankle.r,jointi.ankle.l,...
    jointi.subt.r,jointi.subt.l,...
    jointi.mtp.r,jointi.mtp.l,...
    jointi.trunk.ext,...
    jointi.sh_flex.r:jointi.sh_rot.r,...
    jointi.sh_flex.l:jointi.sh_rot.l,...
    jointi.elb.r,jointi.elb.l];
QsOpp = [jointi.pelvis.list:jointi.pelvis.rot,jointi.pelvis.tz,...
    jointi.trunk.ben:jointi.trunk.rot];
QsSymA_ptx = [jointi.pelvis.tilt,jointi.pelvis.tx,...
    jointi.pelvis.ty,...
    jointi.hip_flex.l:jointi.trunk.ext,...
    jointi.sh_flex.l:jointi.elb.r];
QsSymB_ptx = [jointi.pelvis.tilt,jointi.pelvis.tx,...
    jointi.pelvis.ty,...
    jointi.hip_flex.r:jointi.hip_rot.r,...
    jointi.hip_flex.l:jointi.hip_rot.l,...
    jointi.knee.r,jointi.knee.l,...
    jointi.ankle.r,jointi.ankle.l,...
    jointi.subt.r,jointi.subt.l,...
    jointi.mtp.r,jointi.mtp.l,...
    jointi.trunk.ext,...
    jointi.sh_flex.r:jointi.sh_rot.r,...
    jointi.sh_flex.l:jointi.sh_rot.l,...
    jointi.elb.r,jointi.elb.l];


%% Analyze results

NParameters = 1;
tf_opt = w_opt(1:NParameters);
starti = NParameters+1;
a_opt = reshape(w_opt(starti:starti+NMuscle*(N+1)-1),NMuscle,N+1)';
starti = starti + NMuscle*(N+1);
a_col_opt = reshape(w_opt(starti:starti+NMuscle*(d*N)-1),NMuscle,d*N)';
starti = starti + NMuscle*(d*N);
FTtilde_opt = reshape(w_opt(starti:starti+NMuscle*(N+1)-1),NMuscle,N+1)';
starti = starti + NMuscle*(N+1);
FTtilde_col_opt =reshape(w_opt(starti:starti+NMuscle*(d*N)-1),NMuscle,d*N)';
starti = starti + NMuscle*(d*N);
Qs_opt = reshape(w_opt(starti:starti+nq.all*(N+1)-1),nq.all,N+1)';
starti = starti + nq.all*(N+1);
Qs_col_opt = reshape(w_opt(starti:starti+nq.all*(d*N)-1),nq.all,d*N)';
starti = starti + nq.all*(d*N);
Qdots_opt = reshape(w_opt(starti:starti+nq.all*(N+1)-1),nq.all,N+1)';
starti = starti + nq.all*(N+1);
Qdots_col_opt = reshape(w_opt(starti:starti+nq.all*(d*N)-1),nq.all,d*N)';
starti = starti + nq.all*(d*N);
a_a_opt = reshape(w_opt(starti:starti+nq.arms*(N+1)-1),nq.arms,N+1)';
starti = starti + nq.arms*(N+1);
a_a_col_opt = reshape(w_opt(starti:starti+nq.arms*(d*N)-1),nq.arms,d*N)';
starti = starti + nq.arms*(d*N);
a_mtp_opt = reshape(w_opt(starti:starti+nq.mtp*(N+1)-1),nq.mtp,N+1)';
starti = starti + nq.mtp*(N+1);
a_mtp_col_opt = reshape(w_opt(starti:starti+nq.mtp*(d*N)-1),nq.mtp,d*N)';
starti = starti + nq.mtp*(d*N);
vA_opt = reshape(w_opt(starti:starti+NMuscle*N-1),NMuscle,N)';
starti = starti + NMuscle*N;
e_a_opt = reshape(w_opt(starti:starti+nq.arms*N-1),nq.arms,N)';
starti = starti + nq.arms*N;
e_mtp_opt = reshape(w_opt(starti:starti+nq.mtp*N-1),nq.mtp,N)';
starti = starti + nq.mtp*N;
dFTtilde_col_opt=reshape(w_opt(starti:starti+NMuscle*(d*N)-1),NMuscle,d*N)';
starti = starti + NMuscle*(d*N);
qdotdot_col_opt =reshape(w_opt(starti:starti+nq.all*(d*N)-1),nq.all,(d*N))';
starti = starti + nq.all*(d*N);
if starti - 1 ~= length(w_opt)
    disp('error when extracting results')
end
% Combine results at mesh and collocation points
a_mesh_col_opt=zeros(N*(d+1)+1,NMuscle);
a_mesh_col_opt(1:(d+1):end,:)= a_opt;
FTtilde_mesh_col_opt=zeros(N*(d+1)+1,NMuscle);
FTtilde_mesh_col_opt(1:(d+1):end,:)= FTtilde_opt;
Qs_mesh_col_opt=zeros(N*(d+1)+1,nq.all);
Qs_mesh_col_opt(1:(d+1):end,:)= Qs_opt;
Qdots_mesh_col_opt=zeros(N*(d+1)+1,nq.all);
Qdots_mesh_col_opt(1:(d+1):end,:)= Qdots_opt;
a_a_mesh_col_opt=zeros(N*(d+1)+1,nq.arms);
a_a_mesh_col_opt(1:(d+1):end,:)= a_a_opt;
a_mtp_mesh_col_opt=zeros(N*(d+1)+1,nq.mtp);
a_mtp_mesh_col_opt(1:(d+1):end,:)= a_mtp_opt;
for k=1:N
    rangei = k*(d+1)-(d-1):k*(d+1);
    rangebi = (k-1)*d+1:k*d;
    a_mesh_col_opt(rangei,:) = a_col_opt(rangebi,:);
    FTtilde_mesh_col_opt(rangei,:) = FTtilde_col_opt(rangebi,:);
    Qs_mesh_col_opt(rangei,:) = Qs_col_opt(rangebi,:);
    Qdots_mesh_col_opt(rangei,:) = Qdots_col_opt(rangebi,:);
    a_a_mesh_col_opt(rangei,:) = a_a_col_opt(rangebi,:);
    a_mtp_mesh_col_opt(rangei,:) = a_mtp_col_opt(rangebi,:);
end

%% Unscale results
% States at mesh points
% Qs (1:N-1)
q_opt_unsc.rad = Qs_opt(1:end-1,:).*repmat(...
    scaling.Qs,size(Qs_opt(1:end-1,:),1),1);
% Convert in degrees
q_opt_unsc.deg = q_opt_unsc.rad;
q_opt_unsc.deg(:,roti) = q_opt_unsc.deg(:,roti).*180/pi;
% Qs (1:N)
q_opt_unsc_all.rad = Qs_opt.*repmat(scaling.Qs,size(Qs_opt,1),1);
% Convert in degrees
q_opt_unsc_all.deg = q_opt_unsc_all.rad;
q_opt_unsc_all.deg(:,roti) = q_opt_unsc_all.deg(:,roti).*180/pi;
% Qdots (1:N-1)
qdot_opt_unsc.rad = Qdots_opt(1:end-1,:).*repmat(...
    scaling.Qdots,size(Qdots_opt(1:end-1,:),1),1);
% Convert in degrees
qdot_opt_unsc.deg = qdot_opt_unsc.rad;
qdot_opt_unsc.deg(:,roti) = qdot_opt_unsc.deg(:,roti).*180/pi;
% Qdots (1:N)
qdot_opt_unsc_all.rad =Qdots_opt.*repmat(scaling.Qdots,size(Qdots_opt,1),1);
% Muscle activations (1:N-1)
a_opt_unsc = a_opt(1:end-1,:).*repmat(...
    scaling.a,size(a_opt(1:end-1,:),1),size(a_opt,2));
% Muscle-tendon forces (1:N-1)
FTtilde_opt_unsc = FTtilde_opt(1:end-1,:).*repmat(...
    scaling.FTtilde,size(FTtilde_opt(1:end-1,:),1),1);
% Arm activations (1:N-1)
a_a_opt_unsc = a_a_opt(1:end-1,:);
% Arm activations (1:N)
a_a_opt_unsc_all = a_a_opt;
% Mtp activations (1:N-1)
a_mtp_opt_unsc = a_mtp_opt(1:end-1,:);
% Mtp activations (1:N)
a_mtp_opt_unsc_all = a_mtp_opt;
% Controls at mesh points
% Time derivative of muscle activations (states)
vA_opt_unsc = vA_opt.*repmat(scaling.vA,size(vA_opt,1),size(vA_opt,2));
% Get muscle excitations from time derivative of muscle activations
e_opt_unsc = computeExcitationRaasch(a_opt_unsc,vA_opt_unsc,...
    ones(1,NMuscle)*tdeact,ones(1,NMuscle)*tact);
% Arm excitations
e_a_opt_unsc = e_a_opt;
% Mtp excitations
e_mtp_opt_unsc = e_mtp_opt;
% States at collocation points
% Qs
q_col_opt_unsc.rad = Qs_col_opt.*repmat(scaling.Qs,size(Qs_col_opt,1),1);
% Convert in degrees
q_col_opt_unsc.deg = q_col_opt_unsc.rad;
q_col_opt_unsc.deg(:,roti) = q_col_opt_unsc.deg(:,roti).*180/pi;
% Qdots
qdot_col_opt_unsc.rad = Qdots_col_opt.*repmat(...
    scaling.Qdots,size(Qdots_col_opt,1),1);
% Convert in degrees
qdot_col_opt_unsc.deg = qdot_col_opt_unsc.rad;
qdot_col_opt_unsc.deg(:,roti) = qdot_col_opt_unsc.deg(:,roti).*180/pi;
% Muscle activations
a_col_opt_unsc = a_col_opt.*repmat(...
    scaling.a,size(a_col_opt,1),size(a_col_opt,2));
% Muscle-tendon forces
FTtilde_col_opt_unsc = FTtilde_col_opt.*repmat(...
    scaling.FTtilde,size(FTtilde_col_opt,1),1);
% Arm activations
a_a_col_opt_unsc = a_a_col_opt;
% Mtp activations
a_mtp_col_opt_unsc = a_mtp_col_opt;
% "Slack" controls at collocation points
% Time derivative of Qdots
qdotdot_col_opt_unsc.rad = ...
    qdotdot_col_opt.*repmat(scaling.Qdotdots,size(qdotdot_col_opt,1),1);
% Convert in degrees
qdotdot_col_opt_unsc.deg = qdotdot_col_opt_unsc.rad;
qdotdot_col_opt_unsc.deg(:,roti) = qdotdot_col_opt_unsc.deg(:,roti).*180/pi;
% Time derivative of muscle-tendon forces
dFTtilde_col_opt_unsc = dFTtilde_col_opt.*repmat(...
    scaling.dFTtilde,size(dFTtilde_col_opt,1),size(dFTtilde_col_opt,2));
dFTtilde_opt_unsc = dFTtilde_col_opt_unsc(d:d:end,:);

%% Time grid
% Mesh points
tgrid = linspace(0,tf_opt,N+1);
dtime = zeros(1,d+1);
for i=1:4
    dtime(i)=tau_root(i)*(tf_opt/N);
end
% Mesh points and collocation points
tgrid_ext = zeros(1,(d+1)*N+1);
for i=1:N
    tgrid_ext(((i-1)*4+1):1:i*4)=tgrid(i)+dtime;
end
tgrid_ext(end)=tf_opt;

%% Joint torques and ground reaction forces at mesh points (N-1), except #1
Xk_Qs_Qdots_opt             = zeros(N,2*nq.all);
Xk_Qs_Qdots_opt(:,1:2:end)  = q_opt_unsc_all.rad(2:end,:);
Xk_Qs_Qdots_opt(:,2:2:end)  = qdot_opt_unsc_all.rad(2:end,:);
Xk_Qdotdots_opt             = qdotdot_col_opt_unsc.rad(d:d:end,:);
Foutk_opt = zeros(N,nq.all+NGRF+NcalcOrall);
Tau_passk_opt_all = zeros(N,nq.all-nq.abs);
for i = 1:N
    % ID moments
    [res] = F1([Xk_Qs_Qdots_opt(i,:)';Xk_Qdotdots_opt(i,:)']);
    Foutk_opt(i,:) = full(res);
    % passive moments
    Tau_passk_opt_all(i,:) = full(f_AllPassiveTorques(q_opt_unsc_all.rad(i+1,:),qdot_opt_unsc_all.rad(i+1,:)));
end
GRFk_opt = Foutk_opt(:,GRFi.all);

%% Joint torques and ground reaction forces at collocation points
Xj_Qs_Qdots_opt             = zeros(d*N,2*nq.all);
Xj_Qs_Qdots_opt(:,1:2:end)  = q_col_opt_unsc.rad;
Xj_Qs_Qdots_opt(:,2:2:end)  = qdot_col_opt_unsc.rad;
Xj_Qdotdots_opt             = qdotdot_col_opt_unsc.rad;
Foutj_opt = zeros(d*N,nq.all+NGRF+NcalcOrall);
Tau_passj_opt_all = zeros(d*N,nq.all-nq.abs);
for i = 1:d*N
    % inverse dynamics
    [res] = F1([Xj_Qs_Qdots_opt(i,:)';Xj_Qdotdots_opt(i,:)']);
    Foutj_opt(i,:) = full(res);
    % passive torques
    Tau_passj_opt_all(i,:) = full(f_AllPassiveTorques(q_col_opt_unsc.rad(i,:),qdot_col_opt_unsc.rad(i,:)));
end

%% Stride length and width
% For the stride length we also need the values at the end of the
% interval so N+1 where states but not controls are defined
Xk_Qs_Qdots_opt_all = zeros(N+1,2*size(q_opt_unsc_all.rad,2));
Xk_Qs_Qdots_opt_all(:,1:2:end)  = q_opt_unsc_all.rad;
Xk_Qs_Qdots_opt_all(:,2:2:end)  = qdot_opt_unsc_all.rad;
% We just want to extract the positions of the calcaneus origins so we
% do not really care about Qdotdot that we set to 0
Xk_Qdotdots_opt_all = zeros(N+1,size(q_opt_unsc_all.rad,2));
out_res_opt_all = zeros(N+1,nq.all+NGRF+NcalcOrall);
for i = 1:N+1
    [res] = F1([Xk_Qs_Qdots_opt_all(i,:)';Xk_Qdotdots_opt_all(i,:)']);
    out_res_opt_all(i,:) = full(res);
end
% The stride length is the distance covered by the calcaneus origin
% Right leg
dist_r = sqrt(f_Jnn3(out_res_opt_all(end,calcOrall.r)-...
    out_res_opt_all(1,calcOrall.r)));
% Left leg
dist_l = sqrt(f_Jnn3(out_res_opt_all(end,calcOrall.l)-...
    out_res_opt_all(1,calcOrall.l)));
% The total stride length is the sum of the right and left stride
% lengths after a half gait cycle, since we assume symmetry
StrideLength_opt = full(dist_r + dist_l);
% The stride width is the medial distance between the calcaneus origins
StepWidth_opt = full(abs(out_res_opt_all(:,calcOrall.r(3)) - ...
    out_res_opt_all(:,calcOrall.l(3))));
stride_width_mean = mean(StepWidth_opt);

%% Assert average speed
dist_trav_opt = q_opt_unsc_all.rad(end,jointi.pelvis.tx) - ...
    q_opt_unsc_all.rad(1,jointi.pelvis.tx); % distance traveled
time_elaps_opt = tf_opt; % time elapsed
vel_aver_opt = dist_trav_opt/time_elaps_opt;
% assert_v_tg should be 0
assert_v_tg = abs(vel_aver_opt-v_tgt);
if assert_v_tg > 1*10^(-tol_ipopt)
    disp('Issue when reconstructing average speed')
end

%% Decompose optimal cost
J_opt           = 0;
E_cost          = 0;
A_cost          = 0;
Arm_cost        = 0;
Mtp_cost        = 0;
Qdotdot_cost    = 0;
Pass_cost       = 0;
GRF_cost        = 0;
vA_cost         = 0;
dFTtilde_cost   = 0;
QdotdotArm_cost = 0;
count           = 1;
h_opt           = tf_opt/N;
for k=1:N
    for j=1:d
        % Get muscle-tendon lengths, velocities, moment arms
        % Left leg
        qin_l_opt_all = Xj_Qs_Qdots_opt(count,IndexLeft*2-1);
        qdotin_l_opt_all = Xj_Qs_Qdots_opt(count,IndexLeft*2);
        [lMTk_l_opt_all,vMTk_l_opt_all,~] = ...
            f_lMT_vMT_dM(qin_l_opt_all,qdotin_l_opt_all);
        % Right leg
        qin_r_opt_all = Xj_Qs_Qdots_opt(count,IndexRight*2-1);
        qdotin_r_opt_all = Xj_Qs_Qdots_opt(count,IndexRight*2);
        [lMTk_r_opt_all,vMTk_r_opt_all,~] = ...
            f_lMT_vMT_dM(qin_r_opt_all,qdotin_r_opt_all);
        % Both legs
        lMTk_lr_opt_all = [lMTk_l_opt_all([1:43,47:49],1);lMTk_r_opt_all(1:46,1)];
        vMTk_lr_opt_all = [vMTk_l_opt_all([1:43,47:49],1);vMTk_r_opt_all(1:46,1)];
        % force equilibirum
        [~,~,Fce_opt_all,Fpass_opt_all,Fiso_opt_all,vMmax_opt_all,...
            massM_opt_all] = f_forceEquilibrium_FtildeState_all_tendon(...
            a_col_opt_unsc(count,:)',FTtilde_col_opt_unsc(count,:)',...
            dFTtilde_col_opt_unsc(count,:)',full(lMTk_lr_opt_all),...
            full(vMTk_lr_opt_all),tensions);
        % muscle-tendon kinematics
        [~,lMtilde_opt_all] = f_FiberLength_TendonForce_tendon(...
            FTtilde_col_opt_unsc(count,:)',full(lMTk_lr_opt_all));
        [vM_opt_all,~] = f_FiberVelocity_TendonForce_tendon(...
            FTtilde_col_opt_unsc(count,:)',...
            dFTtilde_col_opt_unsc(count,:)',full(lMTk_lr_opt_all),...
            full(vMTk_lr_opt_all));
        
        % Bhargava et al. (2004)
        [e_tot_all,~,~,~,~,~] = fgetMetabolicEnergySmooth2004all(...
            a_col_opt_unsc(count,:)',a_col_opt_unsc(count,:)',...
            full(lMtilde_opt_all),...
            full(vM_opt_all),full(Fce_opt_all)',full(Fpass_opt_all)',...
            full(massM_opt_all)',pctsts,full(Fiso_opt_all)',body_mass,10);
        e_tot_opt_all = full(e_tot_all)';
        
        % objective function
        J_opt = J_opt + 1/(dist_trav_opt)*(...
            W.E*B(j+1) * (f_J92exp(e_tot_opt_all,exp_E))/body_mass*h_opt + ...
            W.A*B(j+1) * (f_J92(a_col_opt(count,:)))*h_opt +...
            W.ArmE*B(j+1) * (f_J8(e_a_opt(k,:)))*h_opt +...
            W.Mtp*B(j+1) * (f_J2(e_mtp_opt(k,:)))*h_opt +...
            W.Ak*B(j+1) * (f_J23(qdotdot_col_opt(count,residuals_noarmsi)))*h_opt +...
            W.passMom*B(j+1)* (f_J25(Tau_passj_opt_all(count,:)))*h_opt + ...
            W.u*B(j+1) * (f_J92(vA_opt(k,:)))*h_opt + ...
            W.u*B(j+1) * (f_J92(dFTtilde_col_opt(count,:)))*h_opt + ...
            W.u*B(j+1) * (f_J8(qdotdot_col_opt(count,armsi)))*h_opt);
        
        E_cost = E_cost + W.E*B(j+1)*...
            (f_J92exp(e_tot_opt_all,exp_E))/body_mass*h_opt;
        A_cost = A_cost + W.A*B(j+1)*...
            (f_J92(a_col_opt(count,:)))*h_opt;
        Arm_cost = Arm_cost + W.ArmE*B(j+1)*...
            (f_J8(e_a_opt(k,:)))*h_opt;
        Mtp_cost = Mtp_cost + W.Mtp*B(j+1)*...
            (f_J2(e_mtp_opt(k,:)))*h_opt;
        Qdotdot_cost = Qdotdot_cost + W.Ak*B(j+1)*...
            (f_J23(qdotdot_col_opt(count,residuals_noarmsi)))*h_opt;
        Pass_cost = Pass_cost + W.passMom*B(j+1)*...
            (f_J25(Tau_passj_opt_all(count,:)))*h_opt;
        vA_cost = vA_cost + W.u*B(j+1)*...
            (f_J92(vA_opt(k,:)))*h_opt;
        dFTtilde_cost = dFTtilde_cost + W.u*B(j+1)*...
            (f_J92(dFTtilde_col_opt(count,:)))*h_opt;
        QdotdotArm_cost = QdotdotArm_cost + W.u*B(j+1)*...
            (f_J8(qdotdot_col_opt(count,armsi)))*h_opt;
        count = count + 1;
    end
end
J_optf = full(J_opt);
E_costf = full(E_cost);
A_costf = full(A_cost);
Arm_costf = full(Arm_cost);
Mtp_costf = full(Mtp_cost);
Qdotdot_costf = full(Qdotdot_cost);
Pass_costf = full(Pass_cost);
vA_costf = full(vA_cost);
dFTtilde_costf = full(dFTtilde_cost);
QdotdotArm_costf = full(QdotdotArm_cost);
% assertCost should be 0
assertCost = abs(J_optf - 1/(dist_trav_opt)*(E_costf+A_costf+Arm_costf+...
    Mtp_costf+Qdotdot_costf+Pass_costf+vA_costf+dFTtilde_costf+...
    QdotdotArm_costf));
assertCost2 = abs(stats.iterations.obj(end) - J_optf);
if assertCost > 1*10^(-tol_ipopt)
    disp('Issue when reconstructing optimal cost wrt sum of terms')
end
if assertCost2 > 1*10^(-tol_ipopt)
    disp('Issue when reconstructing optimal cost wrt stats')
end

%% Reconstruct full gait cycle
% We reconstruct the full gait cycle from the simulated half gait cycle
% Identify heel strike
threshold = 20; % there is foot-ground contact above the threshold
if exist('HS1','var')
    clear HS1
end

% increase threshold untill you have at least on frame above the threshold
nFramesBelow= sum(GRFk_opt(:,2)<threshold);
while nFramesBelow == 0
    threshold = threshold + 1;
    nFramesBelow= sum(GRFk_opt(:,2)<threshold);
end
phase_tran_tgridi = find(GRFk_opt(:,2)<threshold,1,'last');


if ~isempty(phase_tran_tgridi)
    if phase_tran_tgridi == N
        temp_idx = find(GRFk_opt(:,2)>threshold,1,'first');
        if ~isempty(temp_idx)
            if temp_idx-1 ~= 0 && ...
                    find(GRFk_opt(temp_idx-1,2)<threshold)
                phase_tran_tgridi_t = temp_idx;
                IC1i = phase_tran_tgridi_t;
                HS1 = 'r';
            end
        else
            IC1i = phase_tran_tgridi + 1;
            HS1 = 'r';
        end
    else
        IC1i = phase_tran_tgridi + 1;
        HS1 = 'r';
    end
end
if ~exist('HS1','var')
    % Check if heel strike is on the left side
    phase_tran_tgridi = find(GRFk_opt(:,5)<threshold,1,'last');
    if phase_tran_tgridi == N
        temp_idx = find(GRFk_opt(:,5)>threshold,1,'first');
        if ~isempty(temp_idx)
            if temp_idx-1 ~= 0 && ...
                    find(GRFk_opt(temp_idx-1,5)<threshold)
                phase_tran_tgridi_t = temp_idx;
                IC1i = phase_tran_tgridi_t;
                HS1 = 'l';
            else
                IC1i = phase_tran_tgridi + 1;
                HS1 = 'l';
            end
        else
            IC1i = phase_tran_tgridi + 1;
            HS1 = 'l';
        end
    else
        IC1i = phase_tran_tgridi + 1;
        HS1 = 'l';
    end
end

% GRFk_opt is at mesh points starting from k=2, we thus add 1 to IC1i
% for the states
IC1i_c = IC1i;
IC1i_s = IC1i + 1;

% Qs
Qs_GC = zeros(N*2,size(q_opt_unsc.deg,2));
Qs_GC(1:N-IC1i_s+1,:) = q_opt_unsc.deg(IC1i_s:end,:);
Qs_GC(N-IC1i_s+2:N-IC1i_s+1+N,QsSymA) = q_opt_unsc.deg(1:end,QsSymB);
Qs_GC(N-IC1i_s+2:N-IC1i_s+1+N,QsOpp) = -q_opt_unsc.deg(1:end,QsOpp);
Qs_GC(N-IC1i_s+2:N-IC1i_s+1+N,jointi.pelvis.tx) = ...
    q_opt_unsc.deg(1:end,jointi.pelvis.tx) + ...
    q_opt_unsc_all.deg(end,jointi.pelvis.tx);
Qs_GC(N-IC1i_s+2+N:2*N,:) = q_opt_unsc.deg(1:IC1i_s-1,:);
Qs_GC(N-IC1i_s+2+N:2*N,jointi.pelvis.tx) = ...
    q_opt_unsc.deg(1:IC1i_s-1,jointi.pelvis.tx) + ...
    2*q_opt_unsc_all.deg(end,jointi.pelvis.tx);
% If the first heel strike was on the left foot then we invert so that
% we always start with the right foot, for analysis purpose
if strcmp(HS1,'l')
    Qs_GC(:,QsSymA_ptx)  = Qs_GC(:,QsSymB_ptx);
    Qs_GC(:,QsOpp)       = -Qs_GC(:,QsOpp);
end
temp_Qs_GC_pelvis_tx = Qs_GC(1,jointi.pelvis.tx);
Qs_GC(:,jointi.pelvis.tx) = Qs_GC(:,jointi.pelvis.tx)-...
    temp_Qs_GC_pelvis_tx;

% Qdots
Qdots_GC = zeros(N*2,size(Qs_GC,2));
Qdots_GC(1:N-IC1i_s+1,:) = qdot_opt_unsc.deg(IC1i_s:end,:);
Qdots_GC(N-IC1i_s+2:N-IC1i_s+1+N,QsSymA_ptx) = ...
    qdot_opt_unsc.deg(1:end,QsSymB_ptx);
Qdots_GC(N-IC1i_s+2:N-IC1i_s+1+N,QsOpp) = ...
    -qdot_opt_unsc.deg(1:end,QsOpp);
Qdots_GC(N-IC1i_s+2+N:2*N,:) = qdot_opt_unsc.deg(1:IC1i_s-1,:);
% If the first heel strike was on the left foot then we invert so that
% we always start with the right foot, for analysis purpose
if strcmp(HS1,'l')
    Qdots_GC(:,QsSymA_ptx) = Qdots_GC(:,QsSymB_ptx);
    Qdots_GC(:,QsOpp) = -Qdots_GC(:,QsOpp);
end

% Qdotdots
Qdotdots_GC = zeros(N*2,size(Qs_opt,2));
Qdotdots_GC(1:N-IC1i_c+1,:) = Xk_Qdotdots_opt(IC1i_c:end,:);
Qdotdots_GC(N-IC1i_c+2:N-IC1i_c+1+N,QsSymA_ptx) = ...
    Xk_Qdotdots_opt(1:end,QsSymB_ptx);
Qdotdots_GC(N-IC1i_c+2:N-IC1i_c+1+N,QsOpp) = ...
    -Xk_Qdotdots_opt(1:end,QsOpp);
Qdotdots_GC(N-IC1i_c+2+N:2*N,:) = Xk_Qdotdots_opt(1:IC1i_c-1,:);
% If the first heel strike was on the left foot then we invert so that
% we always start with the right foot, for analysis purpose
if strcmp(HS1,'l')
    Qdotdots_GC(:,QsSymA_ptx) = Qdotdots_GC(:,QsSymB_ptx);
    Qdotdots_GC(:,QsOpp) = -Qdotdots_GC(:,QsOpp);
end

% Ground reaction forces
GRFs_opt = zeros(N*2,NGRF);
GRFs_opt(1:N-IC1i_c+1,:) = GRFk_opt(IC1i_c:end,1:6);
GRFs_opt(N-IC1i_c+2:N-IC1i_c+1+N,:) = GRFk_opt(1:end,[4:6,1:3]);
GRFs_opt(N-IC1i_c+2:N-IC1i_c+1+N,[3,6]) = ...
    -GRFs_opt(N-IC1i_c+2:N-IC1i_c+1+N,[3,6]);
GRFs_opt(N-IC1i_c+2+N:2*N,:) = GRFk_opt(1:IC1i_c-1,1:6);
GRFs_opt = GRFs_opt./(body_weight/100);
% If the first heel strike was on the left foot then we invert so that
% we always start with the right foot, for analysis purpose
if strcmp(HS1,'l')
    GRFs_opt(:,[4:6,1:3]) = GRFs_opt(:,:);
    GRFs_opt(:,[3,6]) = -GRFs_opt(:,[3,6]);
end

% Joint torques
Ts_opt = zeros(N*2,size(Qs_opt,2));
Ts_opt(1:N-IC1i_c+1,1:nq.all) = Foutk_opt(IC1i_c:end,1:nq.all);
Ts_opt(N-IC1i_c+2:N-IC1i_c+1+N,QsSymA_ptx) = Foutk_opt(1:end,QsSymB_ptx);
Ts_opt(N-IC1i_c+2:N-IC1i_c+1+N,QsOpp) = -Foutk_opt(1:end,QsOpp);
Ts_opt(N-IC1i_c+2+N:2*N,1:nq.all) = Foutk_opt(1:IC1i_c-1,1:nq.all);
% If the first heel strike was on the left foot then we invert so that
% we always start with the right foot, for analysis purpose
if strcmp(HS1,'l')
    Ts_opt(:,QsSymA_ptx) = Ts_opt(:,QsSymB_ptx);
    Ts_opt(:,QsOpp) = -Ts_opt(:,QsOpp);
end
Ts_opt = Ts_opt./body_mass;

% Muscle-Tendon Forces
orderMusInv = [NMuscle/2+1:NMuscle,1:NMuscle/2];
FTtilde_GC = zeros(N*2,NMuscle);
FTtilde_GC(1:N-IC1i_s+1,:) = FTtilde_opt_unsc(IC1i_s:end,:);
FTtilde_GC(N-IC1i_s+2:N-IC1i_s+1+N,:) = ...
    FTtilde_opt_unsc(1:end,orderMusInv);
FTtilde_GC(N-IC1i_s+2+N:2*N,:) = FTtilde_opt_unsc(1:IC1i_s-1,:);
% If the first heel strike was on the left foot then we invert so that
% we always start with the right foot, for analysis purpose
if strcmp(HS1,'l')
    FTtilde_GC(:,:) = FTtilde_GC(:,orderMusInv);
end

% Muscle activations
Acts_GC = zeros(N*2,NMuscle);
Acts_GC(1:N-IC1i_s+1,:) = a_opt_unsc(IC1i_s:end,:);
Acts_GC(N-IC1i_s+2:N-IC1i_s+1+N,:) = a_opt_unsc(1:end,orderMusInv);
Acts_GC(N-IC1i_s+2+N:2*N,:) = a_opt_unsc(1:IC1i_s-1,:);
% If the first heel strike was on the left foot then we invert so that
% we always start with the right foot, for analysis purpose
if strcmp(HS1,'l')
    Acts_GC(:,:) = Acts_GC(:,orderMusInv);
end

% Time derivative of muscle-tendon force
dFTtilde_GC = zeros(N*2,NMuscle);
dFTtilde_GC(1:N-IC1i_c+1,:) = dFTtilde_opt_unsc(IC1i_c:end,:);
dFTtilde_GC(N-IC1i_c+2:N-IC1i_c+1+N,:) = ...
    dFTtilde_opt_unsc(1:end,orderMusInv);
dFTtilde_GC(N-IC1i_c+2+N:2*N,:) = dFTtilde_opt_unsc(1:IC1i_c-1,:);
% If the first heel strike was on the left foot then we invert so that
% we always start with the right foot, for analysis purpose
if strcmp(HS1,'l')
    dFTtilde_GC(:,:) = dFTtilde_GC(:,orderMusInv);
end

% Muscle excitations
vA_GC = zeros(N*2,NMuscle);
vA_GC(1:N-IC1i_c+1,:) = vA_opt_unsc(IC1i_c:end,:);
vA_GC(N-IC1i_c+2:N-IC1i_c+1+N,:) = vA_opt_unsc(1:end,orderMusInv);
vA_GC(N-IC1i_c+2+N:2*N,:) = vA_opt_unsc(1:IC1i_c-1,:);
% If the first heel strike was on the left foot then we invert so that
% we always start with the right foot, for analysis purpose
if strcmp(HS1,'l')
    vA_GC(:,:) = vA_GC(:,orderMusInv);
end
e_GC = computeExcitationRaasch(Acts_GC,vA_GC,...
    ones(1,NMuscle)*tdeact,ones(1,NMuscle)*tact);

% Arm activations
orderArmInv = [jointi.sh_flex.r:jointi.sh_rot.r,...
    jointi.sh_flex.l:jointi.sh_rot.l,...
    jointi.elb.r,jointi.elb.l]-jointi.sh_flex.l+1;
a_a_GC = zeros(N*2,nq.arms);
a_a_GC(1:N-IC1i_s+1,:) = a_a_opt_unsc(IC1i_s:end,:);
a_a_GC(N-IC1i_s+2:N-IC1i_s+1+N,:) = a_a_opt_unsc(1:end,orderArmInv);
a_a_GC(N-IC1i_s+2+N:2*N,:) = a_a_opt_unsc(1:IC1i_s-1,:);
% If the first heel strike was on the left foot then we invert so that
% we always start with the right foot, for analysis purpose
if strcmp(HS1,'l')
    a_a_GC(:,:) = a_a_GC(:,orderArmInv);
end

% Mtp activations
orderMtpInv = [jointi.mtp.r,jointi.mtp.l]-jointi.mtp.l+1;
a_mtp_GC = zeros(N*2,nq.mtp);
a_mtp_GC(1:N-IC1i_s+1,:) = a_mtp_opt_unsc(IC1i_s:end,:);
a_mtp_GC(N-IC1i_s+2:N-IC1i_s+1+N,:) = a_mtp_opt_unsc(1:end,orderMtpInv);
a_mtp_GC(N-IC1i_s+2+N:2*N,:) = a_mtp_opt_unsc(1:IC1i_s-1,:);
% If the first heel strike was on the left foot then we invert so that
% we always start with the right foot, for analysis purpose
if strcmp(HS1,'l')
    a_mtp_GC(:,:) = a_mtp_GC(:,orderMtpInv);
end

% Arm excitations
e_a_GC = zeros(N*2,nq.arms);
e_a_GC(1:N-IC1i_c+1,:) = e_a_opt_unsc(IC1i_c:end,:);
e_a_GC(N-IC1i_c+2:N-IC1i_c+1+N,:) = e_a_opt_unsc(1:end,orderArmInv);
e_a_GC(N-IC1i_c+2+N:2*N,:) = e_a_opt_unsc(1:IC1i_c-1,:);
% If the first heel strike was on the left foot then we invert so that
% we always start with the right foot, for analysis purpose
if strcmp(HS1,'l')
    e_a_GC(:,:) = e_a_GC(:,orderArmInv);
end

% Mtp excitations
e_mtp_GC = zeros(N*2,nq.mtp);
e_mtp_GC(1:N-IC1i_c+1,:) = e_mtp_opt_unsc(IC1i_c:end,:);
e_mtp_GC(N-IC1i_c+2:N-IC1i_c+1+N,:) = e_mtp_opt_unsc(1:end,orderMtpInv);
e_mtp_GC(N-IC1i_c+2+N:2*N,:) = e_mtp_opt_unsc(1:IC1i_c-1,:);
% If the first heel strike was on the left foot then we invert so that
% we always start with the right foot, for analysis purpose
if strcmp(HS1,'l')
    e_mtp_GC(:,:) = e_mtp_GC(:,orderMtpInv);
end

% ExoTorques
T_exo_GC = zeros(N*2,2);
T_exo_GC(1:N-IC1i_c+1,:) = ExoVect([1 2],IC1i_c:end)';
T_exo_GC(N-IC1i_c+2:N-IC1i_c+1+N,:) = ExoVect([2 1],1:end)';
T_exo_GC(N-IC1i_c+2+N:2*N,:) = ExoVect([1 2],1:IC1i_c-1)';

% Passive joint torques
Tau_pass_opt_inv = [jointi.hip_flex.r:jointi.hip_rot.r,...
    jointi.hip_flex.l:jointi.hip_rot.l,...
    jointi.knee.r,jointi.knee.l,jointi.ankle.r,jointi.ankle.l,...
    jointi.subt.r,jointi.subt.l,jointi.mtp.r,jointi.mtp.l,...
    jointi.trunk.ext:jointi.trunk.rot,...
    jointi.sh_flex.r:jointi.sh_rot.r,...
    jointi.sh_flex.l:jointi.sh_rot.l,...
    jointi.elb.r,jointi.elb.l]-jointi.hip_flex.l+1;
Tau_pass_opt_GC = zeros(N*2,nq.all-nq.abs);
Tau_pass_opt_GC(1:N-IC1i_c+1,:) = Tau_passk_opt_all(IC1i_c:end,:);
Tau_pass_opt_GC(N-IC1i_c+2:N-IC1i_c+1+N,:) = ...
    Tau_passk_opt_all(1:end,Tau_pass_opt_inv);
Tau_pass_opt_GC(N-IC1i_c+2+N:2*N,:) = Tau_passk_opt_all(1:IC1i_c-1,:);
% If the first heel strike was on the left foot then we invert so that
% we always start with the right foot, for analysis purpose
if strcmp(HS1,'l')
    Tau_pass_opt_GC(:,Tau_pass_opt_inv) = Tau_pass_opt_GC(:,:);
end

% Create .mot file for OpenSim GUI
q_opt_GUI_GC = zeros(2*N,1+nq.all+2);
q_opt_GUI_GC(1:N-IC1i_s+1,1) = tgrid(:,IC1i_s:end-1)';
q_opt_GUI_GC(N-IC1i_s+2:N-IC1i_s+1+N,1)  = tgrid(:,1:end-1)' + tgrid(end);
q_opt_GUI_GC(N-IC1i_s+2+N:2*N,1) = tgrid(:,1:IC1i_s-1)' + 2*tgrid(end);
q_opt_GUI_GC(:,2:end-2) = Qs_GC;
q_opt_GUI_GC(:,end-1:end) = 1.51*180/pi*ones(2*N,2); % pro_sup (locked)
q_opt_GUI_GC(:,1) = q_opt_GUI_GC(:,1)-q_opt_GUI_GC(1,1);
if writeIKmotion
    pathOpenSim = [pathRepo,'/OpenSim'];
    addpath(genpath(pathOpenSim));
    JointAngle.labels = {'time','pelvis_tilt','pelvis_list',...
        'pelvis_rotation','pelvis_tx','pelvis_ty','pelvis_tz',...
        'hip_flexion_l','hip_adduction_l','hip_rotation_l',...
        'hip_flexion_r','hip_adduction_r','hip_rotation_r',...
        'knee_angle_l','knee_angle_r','ankle_angle_l','ankle_angle_r',...
        'subtalar_angle_l','subtalar_angle_r','mtp_angle_l','mtp_angle_r',...
        'lumbar_extension','lumbar_bending','lumbar_rotation',...
        'arm_flex_l','arm_add_l','arm_rot_l',...
        'arm_flex_r','arm_add_r','arm_rot_r',...
        'elbow_flex_l','elbow_flex_r',...
        'pro_sup_l','pro_sup_r'};
    % Two gait cycles
    % Joint angles
    q_opt_GUI_GC_2 = [q_opt_GUI_GC;q_opt_GUI_GC];
    q_opt_GUI_GC_2(2*N+1:4*N,1) = q_opt_GUI_GC_2(2*N+1:4*N,1) + ...
        q_opt_GUI_GC_2(end,1) + ...
        q_opt_GUI_GC_2(end,1)-q_opt_GUI_GC_2(end-1,1);
    q_opt_GUI_GC_2(2*N+1:4*N,jointi.pelvis.tx+1) = ...
        q_opt_GUI_GC_2(2*N+1:4*N,jointi.pelvis.tx+1) + ...
        2*q_opt_unsc_all.deg(end,jointi.pelvis.tx);
    % Muscle activations (to have muscles turning red when activated).
    Acts_GC_GUI = [Acts_GC;Acts_GC];
    % Combine data joint angles and muscle activations
    JointAngleMuscleAct.data = [q_opt_GUI_GC_2,Acts_GC_GUI];
    % Get muscle labels
    muscleNamesAll = cell(1,NMuscle);
    for i = 1:NMuscle/2
        muscleNamesAll{i} = [muscleNames{i}(1:end-2),'_l'];
        muscleNamesAll{i+NMuscle/2} = [muscleNames{i}(1:end-2),'_r'];
    end
    % Combine labels joint angles and muscle activations
    JointAngleMuscleAct.labels = JointAngle.labels;
    for i = 1:NMuscle
        JointAngleMuscleAct.labels{i+size(q_opt_GUI_GC_2,2)} = ...
            [muscleNamesAll{i},'/activation'];
    end
    OutFolder = fullfile(pathRepo,'Results',S.ResultsFolder);
    filenameJointAngles = fullfile(OutFolder,[S.savename '.mot']);
    write_motionFile(JointAngleMuscleAct, filenameJointAngles);
end

%% Metabolic cost of transport for a gait cycle
Qs_opt_rad = Qs_GC;
Qs_opt_rad(:,roti) = Qs_opt_rad(:,roti).*pi/180;
qdot_opt_GC_rad = Qdots_GC;
qdot_opt_GC_rad(:,roti)= qdot_opt_GC_rad(:,roti).*pi/180;
% Pre-allocations
e_mo_opt = zeros(2*N,1);
e_mo_optb = zeros(2*N,1);
vMtilde_opt_all = zeros(2*N, NMuscle);
lMtilde_opt_all = zeros(2*N, NMuscle);
metab_Etot = zeros(2*N, NMuscle);
metab_Adot = zeros(2*N, NMuscle);
metab_Mdot = zeros(2*N, NMuscle);
metab_Sdot = zeros(2*N, NMuscle);
metab_Wdot = zeros(2*N, NMuscle);
FT_opt     = zeros(2*N, NMuscle);
for nn = 1:2*N
    % Get muscle-tendon lengths, velocities, moment arms
    % Left leg
    qin_l_opt = Qs_opt_rad(nn,IndexLeft);
    qdotin_l_opt = qdot_opt_GC_rad(nn,IndexLeft);
    [lMTk_l_opt,vMTk_l_opt,~] = f_lMT_vMT_dM(qin_l_opt,qdotin_l_opt);
    % Right leg
    qin_r_opt = Qs_opt_rad(nn,IndexRight);
    qdotin_r_opt = qdot_opt_GC_rad(nn,IndexRight);
    [lMTk_r_opt,vMTk_r_opt,~] = f_lMT_vMT_dM(qin_r_opt,qdotin_r_opt);
    % Both legs
    lMTk_lr_opt     = [lMTk_l_opt([1:43,47:49],1);lMTk_r_opt(1:46,1)];
    vMTk_lr_opt     = [vMTk_l_opt([1:43,47:49],1);vMTk_r_opt(1:46,1)];
    % force equilibrium
    [~,FT_optt,Fce_optt,Fpass_optt,Fiso_optt,...
        ~,massM_optt] = f_forceEquilibrium_FtildeState_all_tendon(...
        Acts_GC(nn,:)',FTtilde_GC(nn,:)',dFTtilde_GC(nn,:)',full(lMTk_lr_opt),...
        full(vMTk_lr_opt),tensions);
    % fiber kinematics
    [~,lMtilde_opt] = f_FiberLength_TendonForce_tendon(...
        FTtilde_GC(nn,:)',full(lMTk_lr_opt));
    lMtilde_opt_all(nn,:) = full(lMtilde_opt)';
    [vM_opt,vMtilde_opt] = f_FiberVelocity_TendonForce_tendon(FTtilde_GC(nn,:)',...
        dFTtilde_GC(nn,:)',full(lMTk_lr_opt),full(vMTk_lr_opt));
    vMtilde_opt_all(nn,:) = full(vMtilde_opt)';
    % Bhargava et al. (2004)
    [energy_total,Adot,Mdot,Sdot,Wdot,e_mot] = ...
        fgetMetabolicEnergySmooth2004all(Acts_GC(nn,:)',...
        Acts_GC(nn,:)',full(lMtilde_opt),full(vM_opt),...
        full(Fce_optt),full(Fpass_optt),full(massM_optt),pctsts,...
        full(Fiso_optt)',body_mass,10);
    e_mo_opt(nn,:) = full(e_mot)';
    e_mo_optb(nn,:) = full(e_mot)';
    metab_Etot(nn,:) = full(energy_total)';
    metab_Adot(nn,:) = full(Adot)';
    metab_Mdot(nn,:) = full(Mdot)';
    metab_Sdot(nn,:) = full(Sdot)';
    metab_Wdot(nn,:) = full(Wdot)';
    FT_opt(nn,:)     = full(FT_optt)';
end
% Get COT
dist_trav_opt_GC = Qs_opt_rad(end,jointi.pelvis.tx) - ...
    Qs_opt_rad(1,jointi.pelvis.tx); % distance traveled
time_GC = q_opt_GUI_GC(:,1);
e_mo_opt_trb = trapz(time_GC,e_mo_optb);
% Cost of transport: J/kg/m
% Energy model from Bhargava et al. (2004)
COT_GC = e_mo_opt_trb/body_mass/dist_trav_opt_GC;

%% Save results
% Structure Results_all
R.t_step    = tgrid;
R.tf_step   = tgrid(end);
R.t         = q_opt_GUI_GC(:,1);
R.tend      = q_opt_GUI_GC(end,1) - q_opt_GUI_GC(1,1);
R.Qs        = Qs_GC;
R.Qdots     = Qdots_GC;
R.GRFs      = GRFs_opt;
R.Ts        = Ts_opt;
R.Tid       = Ts_opt.*body_mass;
R.a         = Acts_GC;
R.e         = e_GC;
R.COT       = COT_GC;
R.StrideLength = StrideLength_opt;
R.StepWidth = stride_width_mean;
R.vMtilde   = vMtilde_opt_all;
R.lMtilde   = lMtilde_opt_all;
R.MetabB.Etot = metab_Etot;
R.MetabB.Adot = metab_Adot;
R.MetabB.Mdot = metab_Mdot;
R.MetabB.Sdot = metab_Sdot;
R.MetabB.Wdot = metab_Wdot;
R.ExoControl  = ExoControl;
R.S           = S;  % settings for post processing
R.Sopt        = Sopt; % original settings used to solve the OCP
R.body_mass   = body_mass;
R.a_arm       = a_a_GC;
R.e_arm       = e_a_GC;
R.a_mtp       = a_mtp_GC;
R.e_mtp       = e_mtp_GC;
R.FT          = FT_opt;
R.TPass       = Tau_pass_opt_GC;
R.dt          = nanmean(diff(R.t));
R.T_exo       = T_exo_GC;
R.dt_exoShift = IC1i_c.*R.dt;

% header information
R.colheaders.joints = joints;
R.colheaders.GRF = {'fore_aft_r','vertical_r',...
    'lateral_r','fore_aft_l','vertical_l','lateral_l'};
for i = 1:NMuscle/2
    R.colheaders.muscles{i} = ...
        [muscleNames{i}(1:end-2),'_l'];
    R.colheaders.muscles{i+NMuscle/2} = ...
        [muscleNames{i}(1:end-2),'_r'];
end
% script information
R.info.script = 'f_LoadSim_PoggenSee2020.m';
% Save data
OutFolder = fullfile(pathRepo,'Results',S.ResultsFolder);
FilenameAnalysis = fullfile(OutFolder,[S.savename '_pp.mat']);
save(FilenameAnalysis,'R');




end
