

%% Static equilibrium

% to goal of this function is to compute metabolic energy in the static
% situation. We only analyse one frame and solve for the muscle states.

clear all; close all;
%% Settings
S.mass = 62;
S.subject = 's1_Poggensee';
S.CasadiFunc_Folders  = 'Casadi_s1_Poggensee';
S.ifr = 1; % frame used in the analysis
pathmain = pwd;
[pathRepo,~,~] = fileparts(pwd);
import casadi.*

%% Load the casadi functions
pathCasADiFunctions = [pathRepo,'/CasADiFunctions'];
PathDefaultFunc = fullfile(pathCasADiFunctions,S.CasadiFunc_Folders);
cd(PathDefaultFunc);
% f_coll = Function.load('f_coll');
f_ArmActivationDynamics = Function.load('f_ArmActivationDynamics');
f_FiberLength_TendonForce_tendon = Function.load('f_FiberLength_TendonForce_tendon');
f_FiberVelocity_TendonForce_tendon = Function.load('f_FiberVelocity_TendonForce_tendon');
f_forceEquilibrium_FtildeState_all_tendon = Function.load('f_forceEquilibrium_FtildeState_all_tendon');
f_J2    = Function.load('f_J2');
f_J23   = Function.load('f_J23');
f_J25   = Function.load('f_J25');
f_J8    = Function.load('f_J8');
f_J92   = Function.load('f_J92');
f_J92exp = Function.load('f_J92exp');
f_Jnn2  = Function.load('f_Jnn2');
f_Jnn3  = Function.load('f_Jnn3');
f_lMT_vMT_dM = Function.load('f_lMT_vMT_dM');
f_MtpActivationDynamics = Function.load('f_MtpActivationDynamics');
% f_PassiveMoments = Function.load('f_PassiveMoments');
% f_passiveTATorque = Function.load('f_passiveTATorque');
f_T12 = Function.load('f_T12');
f_T13 = Function.load('f_T13');
f_T27 = Function.load('f_T27');
f_T6 = Function.load('f_T6');
f_AllPassiveTorques = Function.load('f_AllPassiveTorques');
fgetMetabolicEnergySmooth2004all = Function.load('fgetMetabolicEnergySmooth2004all');
cd(pathmain);


%% load the metalbolic energy equations
PathDefaultFunc = fullfile(pathCasADiFunctions,'EnergyModels');
cd(PathDefaultFunc);
fgetMetabolicEnergySmooth2003all    = Function.load('fgetMetabolicEnergySmooth2003all');
fgetMetabolicEnergySmooth2010all    = Function.load('fgetMetabolicEnergySmooth2010all');
fgetMetabolicEnergySmooth2016all    = Function.load('fgetMetabolicEnergySmooth2016all');
fgetMetabolicEnergySmooth2010all_hl = Function.load('fgetMetabolicEnergySmooth2010all_hl');
fgetMetabolicEnergySmooth2010all_neg= Function.load('fgetMetabolicEnergySmooth2010all_neg');
fgetMetabolicEnergy_MargariaSmooth  = Function.load('fgetMetabolicEnergy_MargariaSmooth');
cd(pathmain);

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
pathmusclemodel = fullfile(pathRepo,'MuscleModel',S.subject);
musi = MuscleIndices(muscleNames(1:end-3));
NMuscle = length(muscleNames(1:end-3))*2;
ExtPoly = '_mtp';
load([pathmusclemodel,'/MTparameters_',S.subject, ExtPoly, '.mat']);
MTparameters_m = [MTparameters(:,musi),MTparameters(:,musi)];

% Muscle-tendon parameters. Row 1: maximal isometric forces; Row 2: optimal
% fiber lengths; Row 3: tendon slack lengths; Row 4: optimal pennation
% angles; Row 5: maximal contraction velocities
pathpolynomial = fullfile(pathRepo,'Polynomials',S.subject);
addpath(genpath(pathpolynomial));
tl = load([pathpolynomial,'/muscle_spanning_joint_INFO_',S.subject,'_mtp.mat']);
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



%% Get input information

% standard indexes
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

% indexes to select kinematics left and right leg
IndexLeft = [jointi.hip_flex.l jointi.hip_add.l jointi.hip_rot.l, ...
    jointi.knee.l jointi.ankle.l jointi.subt.l jointi.mtp.l,...
    jointi.trunk.ext, jointi.trunk.ben, jointi.trunk.rot];
IndexRight = [jointi.hip_flex.r jointi.hip_add.r jointi.hip_rot.r, ...
    jointi.knee.r jointi.ankle.r jointi.subt.r jointi.mtp.r,...
    jointi.trunk.ext, jointi.trunk.ben, jointi.trunk.rot];


% get IK and ID data in the right format
IK = importdata('IKsolution.mot');
ID = importdata('inverse_dynamics.sto');
iPelvis = [2 3 4 5 6 7];
iHips = [8:10 15:17];
iKnee = [11 18];
iAnkle = [12 19];
iSubt = [13 20];
imtp = [14 21];
itrunk = [22 23 24];
iSel = [iPelvis iHips iKnee iAnkle iSubt imtp itrunk];
nfr = length(IK.data(:,1));
IndsRot = [1:3 7:31];

% all frames
qv = [IK.data(:,iSel) zeros(nfr,8)];
qv(:,IndsRot) = qv(:,IndsRot)*pi./180;   % conver to radians
qdotv = zeros(nfr,31);
Tidv= [ID.data(:,iSel) zeros(nfr,8)];

% one frame
q = qv(S.ifr,:);
qdot = qdotv(S.ifr,:);
Tid= Tidv(S.ifr,:);

% select left and right kinematics and kinetics
qr = q(IndexLeft);
ql = q(IndexRight);
qdotr = qdot(IndexLeft);
qdotl = qdot(IndexRight);


[lMTj_l,vMTj_l,MAj_l] =  f_lMT_vMT_dM(ql,qdotl);
MAj.hip_flex.l   =  MAj_l(mai(1).mus.l',1);
MAj.hip_add.l    =  MAj_l(mai(2).mus.l',2);
MAj.hip_rot.l    =  MAj_l(mai(3).mus.l',3);
MAj.knee.l       =  MAj_l(mai(4).mus.l',4);
MAj.ankle.l      =  MAj_l(mai(5).mus.l',5);
MAj.subt.l       =  MAj_l(mai(6).mus.l',6);
% For the back muscles, we want left and right together: left
% first, right second. In MuscleInfo, we first have the right
% muscles (44:46) and then the left muscles (47:49). Since the back
% muscles only depend on back dofs, we do not care if we extract
% them "from the left or right leg" so here we just picked left.
MAj.trunk_ext    =  MAj_l([47:49,mai(8).mus.l]',8);
MAj.trunk_ben    =  MAj_l([47:49,mai(9).mus.l]',9);
MAj.trunk_rot    =  MAj_l([47:49,mai(10).mus.l]',10);
% Right leg

[lMTj_r,vMTj_r,MAj_r] =  f_lMT_vMT_dM(qr,qdotr);
% Here we take the indices from left since the vector is 1:49
MAj.hip_flex.r   =  MAj_r(mai(1).mus.l',1);
MAj.hip_add.r    =  MAj_r(mai(2).mus.l',2);
MAj.hip_rot.r    =  MAj_r(mai(3).mus.l',3);
MAj.knee.r       =  MAj_r(mai(4).mus.l',4);
MAj.ankle.r      =  MAj_r(mai(5).mus.l',5);
MAj.subt.r       =  MAj_r(mai(6).mus.l',6);
% Both legs
% In MuscleInfo, we first have the right back muscles (44:46) and
% then the left back muscles (47:49). Here we re-organize so that
% we have first the left muscles and then the right muscles.
lMTj_lr = [lMTj_l([1:43,47:49],1);lMTj_r(1:46,1)];
vMTj_lr = [vMTj_l([1:43,47:49],1);vMTj_r(1:46,1)];

%% solve for muscle states

opti = casadi.Opti();

a = opti.variable(1,92);
Ftilde = opti.variable(1,92);
dFtilde = zeros(1,92);

opti.subject_to(0.01  < a < 1);
opti.subject_to(0  < Ftilde < 1);

% get the torque equilibrium
[Hilldiffj,FTj,Fcej,Fpassj,Fisoj,vMmaxj,massMj] = f_forceEquilibrium_FtildeState_all_tendon(a,...
    Ftilde,dFtilde,lMTj_lr,vMTj_lr,tensions);

opti.subject_to(Hilldiffj == 0);


% Hip flexion, left
Ft_hip_flex_l   = FTj(mai(1).mus.l',1);
T_hip_flex_l    = f_T27(MAj.hip_flex.l,Ft_hip_flex_l);
% Hip flexion, right
Ft_hip_flex_r   = FTj(mai(1).mus.r',1);
T_hip_flex_r    = f_T27(MAj.hip_flex.r,Ft_hip_flex_r);
% Hip adduction, left
Ft_hip_add_l    = FTj(mai(2).mus.l',1);
T_hip_add_l     = f_T27(MAj.hip_add.l,Ft_hip_add_l);
% Hip adduction, right
Ft_hip_add_r    = FTj(mai(2).mus.r',1);
T_hip_add_r     = f_T27(MAj.hip_add.r,Ft_hip_add_r);
% Hip rotation, left
Ft_hip_rot_l    = FTj(mai(3).mus.l',1);
T_hip_rot_l     = f_T27(MAj.hip_rot.l,Ft_hip_rot_l);
% Hip rotation, right
Ft_hip_rot_r    = FTj(mai(3).mus.r',1);
T_hip_rot_r     = f_T27(MAj.hip_rot.r,Ft_hip_rot_r);
% Knee, left
Ft_knee_l       = FTj(mai(4).mus.l',1);
T_knee_l        = f_T13(MAj.knee.l,Ft_knee_l);
% Knee, right
Ft_knee_r       = FTj(mai(4).mus.r',1);
T_knee_r        = f_T13(MAj.knee.r,Ft_knee_r);
% Ankle, left
Ft_ankle_l      = FTj(mai(5).mus.l',1);
T_ankle_l       = f_T12(MAj.ankle.l,Ft_ankle_l);
% Ankle, right
Ft_ankle_r      = FTj(mai(5).mus.r',1);
T_ankle_r       = f_T12(MAj.ankle.r,Ft_ankle_r);
% Subtalar, left
Ft_subt_l       = FTj(mai(6).mus.l',1);
T_subt_l        = f_T12(MAj.subt.l,Ft_subt_l);
% Subtalar, right
Ft_subt_r       = FTj(mai(6).mus.r',1);
T_subt_r        = f_T12(MAj.subt.r,Ft_subt_r);
% Lumbar extension
Ft_trunk_ext    = FTj([mai(8).mus.l,mai(8).mus.r]',1);
T_trunk_ext     = f_T6(MAj.trunk_ext,Ft_trunk_ext);
% Lumbar bending
Ft_trunk_ben    = FTj([mai(9).mus.l,mai(9).mus.r]',1);
T_trunk_ben     = f_T6(MAj.trunk_ben,Ft_trunk_ben);
% Lumbar rotation
Ft_trunk_rot    = FTj([mai(10).mus.l,mai(10).mus.r]',1);
T_trunk_rot     = f_T6(MAj.trunk_rot,Ft_trunk_rot);

% Muscle torques
TmuscleL = [T_hip_flex_l T_hip_add_l T_hip_rot_l  T_knee_l  T_ankle_l T_subt_l];
TmuscleR = [T_hip_flex_r T_hip_add_r T_hip_rot_r  T_knee_r  T_ankle_r T_subt_r];
TmuscleLumbar = [T_trunk_ext T_trunk_ben T_trunk_rot];

% equilibrium torques

opti.subject_to(TmuscleL - Tid(:,IndexLeft(1:end-4)) == 0);
opti.subject_to(TmuscleR - Tid(:,IndexRight(1:end-4)) == 0);
opti.subject_to(TmuscleLumbar - Tid(:,jointi.trunk.ext:jointi.trunk.rot) == 0);
% objective
opti.minimize(sumsqr(a));

% solve
options.ipopt.hessian_approximation = 'limited-memory';
options.ipopt.mu_strategy           = 'adaptive';
options.ipopt.max_iter              = 10000;
options.ipopt.linear_solver         = 'mumps';
options.ipopt.tol                   = 1*10^(-6);
opti.solver('ipopt', options);

% solve the problem
sol = opti.solve();

% solution
R.a = value(sol,a);
R.Ftilde = value(sol,Ftilde);
R.dFtilde = dFtilde;

%% compute metabolic energy from the solution
body_mass = S.mass;
b = 1000;

vMT_lr = zeros(1,92);

% fiber kinematics
[~,lMtilde_opt] = f_FiberLength_TendonForce_tendon(R.Ftilde,full(lMTj_lr));
lMtilde = full(lMtilde_opt)';
[vM_opt,vMtilde_opt] = f_FiberVelocity_TendonForce_tendon(R.Ftilde,...
    R.dFtilde,full(lMTj_lr),full(vMT_lr));
vMtilde = full(vMtilde_opt)';

% Bhargava et al. (2004)
[energy_total,Adot,Mdot,Sdot,Wdot,eBargh] = ...
    fgetMetabolicEnergySmooth2004all(R.a,...
    R.a,lMtilde,full(vM_opt),...
    full(Fcej),full(Fpassj),full(massMj),pctsts,...
    full(Fisoj),body_mass,b);

% Umberger 2003
vMtildeUmbk_opt = full(vM_opt)./(MTparameters_m(2,:)');
[eUmb2003,~,~,~,eUmb2003B] = fgetMetabolicEnergySmooth2003all(...
    R.a,R.a,lMtilde,...
    vMtildeUmbk_opt,full(vM_opt),full(Fcej),...
    full(massMj),pctsts,10,...
    full(Fisoj)',body_mass,b);

% Umberger 2010
[eUmb2010,~,~,~,eUmb2010B] = fgetMetabolicEnergySmooth2010all(...
    R.a,R.a,lMtilde,...
    vMtildeUmbk_opt,full(vM_opt),full(Fcej),...
    full(massMj),pctsts,10,...
    full(Fisoj),body_mass,b);

% Uchida et al. (2016)
[eUchida2016,~,~,~,eUchida2016B] = fgetMetabolicEnergySmooth2016all(...
    R.a,R.a,lMtilde,...
    vMtildeUmbk_opt,full(vM_opt),full(Fcej),...
    full(massMj),pctsts,10,...
    full(Fisoj),body_mass,b);

% Umberger (2010) treating muscle lengthening
% heat rate as Umberger et al. (2003)
% vMtilde defined for this model as vM/lMopt
[eUmb2010_h1,~,~,~,eUmb2010_h1B] = fgetMetabolicEnergySmooth2010all_hl(...
    R.a,R.a,lMtilde,...
    vMtildeUmbk_opt,full(vM_opt),full(Fcej),...
    full(massMj),pctsts,10,...
    full(Fisoj),body_mass,1000);

% Umberger (2010) treating negative mechanical
% work as Umberger et al. (2003)
% vMtilde defined for this model as vM/lMopt
[eUmb2010_neg,~,~,~,eUmb2010_negB] = fgetMetabolicEnergySmooth2010all_neg(...
    R.a,R.a,lMtilde,...
    vMtildeUmbk_opt,full(vM_opt),full(Fcej),...
    full(massMj),pctsts,10,...
    full(Fisoj),body_mass,b);

% Margaria 1968
eMarg1968 = fgetMetabolicEnergy_MargariaSmooth(full(Fcej),full(vM_opt)');


%% save the metabolic power during standing
Edot.Bargh2004        = sol.value(sum(energy_total));
EdotBasal.Bargh2004   = sol.value(eBargh);
Edot.eUmb2003         = sol.value(sum(eUmb2003));
EdotBasal.eUmb2003    = sol.value(eUmb2003B);
Edot.eUmb2010         = sol.value(sum(eUmb2010));
EdotBasal.eUmb2010    = sol.value(eUmb2010B);
Edot.eUchida2016      = sol.value(sum(eUchida2016));
EdotBasal.eUchida2016 = sol.value(eUchida2016B);
Edot.eUmb2010_h1      = sol.value(sum(eUmb2010_h1));
EdotBasal.eUmb2010_h1 = sol.value(eUmb2010_h1B);
Edot.eUmb2010_neg     = sol.value(sum(eUmb2010_neg));
EdotBasal.eUmb2010_neg = sol.value(eUmb2010_negB);
Edot.eMarg1968        = sol.value(sum(eMarg1968));
EdotBasal.eMarg1968   = sol.value(eMarg1968);

%% save metabolic energy

save(['MetabRate_Standing_' S.subject '.mat'],'Edot','EdotBasal');
disp(Edot);


