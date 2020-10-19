% This script contains several CasADi-based functions that are
% used when solving the OCPs
%
% Author: Antoine Falisse
% Date: 12/19/2018
%

clear all; close all; clc;
import casadi.*
ExtPoly = '';
S.CasadiFunc_Folders = 'Casadi_Rajagopal2015';
subject              = 'Rajagopal2015';
% if isfolder(S.CasadiFunc_Folders)
%     error('Never changes the casadi functions in an existing folder, these functions are important to analyse optimization results (from the optimal states and controls');
% end
pathRepo        = 'C:\Users\u0088756\Documents\FWO\Software\ExoSim\SimExo_3D\3dpredictsim';
nq.leg          = 7; % #joints needed for polynomials
stiffnessArm    = 0;
dampingArm      = 0.1;
stiffnessMtp    = 1.5/(pi/180)/5;
dampingMtp      = 0.5;
% define general settings for default objective functions
% By default, the tendon stiffness is 35 and the shift is 0.
NMuscle = 80;
aTendon = 35*ones(NMuscle,1);
% IndexCalf = [32 33 34 78 79 80];    % adjust stiffness of the calf muscles
% aTendon(IndexCalf) = 35;
shift = getShift(aTendon);
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
nq.leg      = 7; % #joints needed for polynomials
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


%% Muscle-tendon parameters
% Muscles from one leg and from the back
muscleNames = {'addbrev_r','addlong_r','addmagDist_r','addmagIsch_r','addmagMid_r','addmagProx_r',...
    'bflh_r','bfsh_r','edl_r','ehl_r','fdl_r','fhl_r','gaslat_r','gasmed_r','glmax1_r','glmax2_r',...
    'glmax3_r','glmed1_r','glmed2_r','glmed3_r','glmin1_r','glmin2_r','glmin3_r','grac_r','iliacus_r',...
    'perbrev_r','perlong_r','piri_r','psoas_r','recfem_r','sart_r','semimem_r','semiten_r','soleus_r',...
    'tfl_r','tibant_r','tibpost_r','vasint_r','vaslat_r','vasmed_r'};
% Muscle indices for later use
pathmusclemodel = fullfile(pathRepo,'MuscleModel',subject);
addpath(genpath(pathmusclemodel));
% (1:end-3), since we do not want to count twice the back muscles
musi = 1:40;
% Total number of muscles
NMuscle = length(muscleNames)*2;
% Muscle-tendon parameters. Row 1: maximal isometric forces; Row 2: optimal
% fiber lengths; Row 3: tendon slack lengths; Row 4: optimal pennation
% angles; Row 5: maximal contraction velocities
load([pathmusclemodel,'/MTparameters_',subject, ExtPoly, '.mat']);
MTparameters_m = [MTparameters(:,musi),MTparameters(:,musi)];
% Indices of the muscles actuating the different joints for later use
pathpolynomial = fullfile(pathRepo,'Polynomials',subject);
addpath(genpath(pathpolynomial));
tl = load([pathpolynomial,'/muscle_spanning_joint_INFO_',subject,ExtPoly, '.mat']);
[~,mai] = MomentArmIndices(muscleNames,tl.muscle_spanning_joint_INFO);

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
addpath(genpath(pathCasADiFunctions));
% We load some variables for the polynomial approximations
load([pathpolynomial,'/muscle_spanning_joint_INFO_',subject,ExtPoly, '.mat']);
load([pathpolynomial,'/MuscleInfo_',subject,ExtPoly,'.mat']);
% For the polynomials, we want all independent muscles. So we do not need
% the muscles from both legs, since we assume bilateral symmetry, but want
% all muscles from the back (indices 47:49).
musi_pol = musi;
NMuscle_pol = NMuscle/2;

%% Polynomial approximation
muscle_spanning_info_m = muscle_spanning_joint_INFO(musi_pol,:);
MuscleInfo_m.muscle    = MuscleInfo.muscle(musi_pol);
qin     = SX.sym('qin',1,nq.leg);
qdotin  = SX.sym('qdotin',1,nq.leg);
lMT     = SX(NMuscle_pol,1);
vMT     = SX(NMuscle_pol,1);
dM      = SX(NMuscle_pol,nq.leg);
for i=1:NMuscle_pol
    index_dof_crossing  = find(muscle_spanning_info_m(i,:)==1);
    order               = MuscleInfo_m.muscle(i).order;
    [mat,diff_mat_q]    = n_art_mat_3_cas_SX(qin(1,index_dof_crossing),...
        order);
    lMT(i,1)            = mat*MuscleInfo_m.muscle(i).coeff;
    vMT(i,1)            = 0;
    dM(i,1:nq.leg)      = 0;
    nr_dof_crossing     = length(index_dof_crossing);
    for dof_nr = 1:nr_dof_crossing
        dM(i,index_dof_crossing(dof_nr)) = ...
            (-(diff_mat_q(:,dof_nr)))'*MuscleInfo_m.muscle(i).coeff;
        vMT(i,1) = vMT(i,1) + (-dM(i,index_dof_crossing(dof_nr))*...
            qdotin(1,index_dof_crossing(dof_nr)));
    end
end
f_lMT_vMT_dM = Function('f_lMT_vMT_dM',{qin,qdotin},{lMT,vMT,dM},...
    {'qin','qdotin'},{'lMT','vMT','dM'});

%% Normalized sum of squared values
% Function for 8 elements
etemp8 = SX.sym('etemp8',8);
Jtemp8 = 0;
for i=1:length(etemp8)
    Jtemp8 = Jtemp8 + etemp8(i).^2;
end
Jtemp8 = Jtemp8/8;
f_J8 = Function('f_J8',{etemp8},{Jtemp8});
% Function for 25 elements
etemp25 = SX.sym('etemp25',25);
Jtemp25 = 0;
for i=1:length(etemp25)
    Jtemp25 = Jtemp25 + etemp25(i).^2;
end
Jtemp25 = Jtemp25/25;
f_J25 = Function('f_J25',{etemp25},{Jtemp25});
% Function for 23 elements
etemp23 = SX.sym('etemp23',23);
Jtemp23 = 0;
for i=1:length(etemp23)
    Jtemp23 = Jtemp23 + etemp23(i).^2;
end
Jtemp23 = Jtemp23/23;
f_J23 = Function('f_J23',{etemp23},{Jtemp23});
% Function for 92 elements
etemp92 = SX.sym('etemp92',92);
Jtemp92 = 0;
for i=1:length(etemp92)
    Jtemp92 = Jtemp92 + etemp92(i).^2;
end
Jtemp92 = Jtemp92/92;
f_J92 = Function('f_J92',{etemp92},{Jtemp92});
% Function for 80 elements
etemp80 = SX.sym('etemp80',80);
Jtemp80 = 0;
for i=1:length(etemp80)
    Jtemp80 = Jtemp80 + etemp80(i).^2;
end
Jtemp80 = Jtemp80/80;
f_J80 = Function('f_J80',{etemp80},{Jtemp80});
% Function for 2 elements
etemp2 = SX.sym('etemp2',2);
Jtemp2 = 0;
for i=1:length(etemp2)
    Jtemp2 = Jtemp2 + etemp2(i).^2;
end
Jtemp2 = Jtemp2/2;
f_J2 = Function('f_J2',{etemp2},{Jtemp2});

% Function for 3 elements
etemp3 = SX.sym('etemp3',3);
Jtemp3 = 0;
for i=1:length(etemp3)
    Jtemp3 = Jtemp3 + etemp3(i).^2;
end
Jtemp3 = Jtemp3/3;
f_J3 = Function('f_J3',{etemp3},{Jtemp3});

% Function for 30 elements
etemp30 = SX.sym('etemp30',30);
Jtemp30 = 0;
for i=1:length(etemp30)
    Jtemp30 = Jtemp30 + etemp30(i).^2;
end
Jtemp30 = Jtemp30/30;
f_J30 = Function('f_J30',{etemp30},{Jtemp30});

% Function for 6 elements
etemp6 = SX.sym('etemp6',6);
Jtemp6 = 0;
for i=1:length(etemp6)
    Jtemp6 = Jtemp6 + etemp6(i).^2;
end
Jtemp6 = Jtemp6/6;
f_J6 = Function('f_J6',{etemp6},{Jtemp6});


%% Sum of squared values (non-normalized)
% Function for 3 elements
etemp3 = SX.sym('etemp3',3);
Jtemp3 = 0;
for i=1:length(etemp3)
    Jtemp3 = Jtemp3 + etemp3(i).^2;
end
f_Jnn3 = Function('f_Jnn3',{etemp3},{Jtemp3});
% Function for 2 elements
etemp2 = SX.sym('etemp2',2);
Jtemp2 = 0;
for i=1:length(etemp2)
    Jtemp2 = Jtemp2 + etemp2(i).^2;
end
f_Jnn2 = Function('f_Jnn2',{etemp2},{Jtemp2});

%% Normalized sum of values to a certain power
% Function for 92 elements
etemp92exp  = SX.sym('etemp92exp',92);
expo        = SX.sym('exp',1);
Jtemp92exp = 0;
for i=1:length(etemp92exp)
    Jtemp92exp = Jtemp92exp + etemp92exp(i).^expo;
end
Jtemp92exp = Jtemp92exp/92;
f_J92exp = Function('f_J92exp',{etemp92exp,expo},{Jtemp92exp});
% Function for 80 elements
etemp80exp  = SX.sym('etemp80exp',80);
expo        = SX.sym('exp',1);
Jtemp80exp = 0;
for i=1:length(etemp80exp)
    Jtemp80exp = Jtemp80exp + etemp80exp(i).^expo;
end
Jtemp80exp = Jtemp80exp/80;
f_J80exp = Function('f_J80exp',{etemp80exp,expo},{Jtemp80exp});

%% Sum of products
% Function for 27 elements
ma_temp27 = SX.sym('ma_temp27',27);
ft_temp27 = SX.sym('ft_temp27',27);
J_sptemp27 = 0;
for i=1:length(ma_temp27)
    J_sptemp27 = J_sptemp27 + ma_temp27(i,1)*ft_temp27(i,1);
end
f_T27 = Function('f_T27',{ma_temp27,ft_temp27},{J_sptemp27});
% Function for 13 elements
ma_temp13 = SX.sym('ma_temp13',13);
ft_temp13 = SX.sym('ft_temp13',13);
J_sptemp13 = 0;
for i=1:length(ma_temp13)
    J_sptemp13 = J_sptemp13 + ma_temp13(i,1)*ft_temp13(i,1);
end
f_T13 = Function('f_T13',{ma_temp13,ft_temp13},{J_sptemp13});
% Function for 12 elements
ma_temp12 = SX.sym('ma_temp12',12);
ft_temp12 = SX.sym('ft_temp12',12);
J_sptemp12 = 0;
for i=1:length(ma_temp12)
    J_sptemp12 = J_sptemp12 + ma_temp12(i,1)*ft_temp12(i,1);
end
f_T12 = Function('f_T12',{ma_temp12,ft_temp12},{J_sptemp12});
% Function for 6 elements
ma_temp6 = SX.sym('ma_temp6',6);
ft_temp6 = SX.sym('ft_temp6',6);
J_sptemp6 = 0;
for i=1:length(ma_temp6)
    J_sptemp6 = J_sptemp6 + ma_temp6(i,1)*ft_temp6(i,1);
end
f_T6 = Function('f_T6',{ma_temp6,ft_temp6},{J_sptemp6});

%% Sum of products for specific joints

% Function for hip flexion
nMus = length(mai(1).mus.l);
dM = SX.sym('dM',nMus);
Fmus = SX.sym('Fmus',nMus);
Jtemp = 0;
for i=1:length(dM)
    Jtemp = Jtemp + dM(i,1)*Fmus(i,1);
end
f_THipFlex = Function('f_THipFlex',{dM,Fmus},{Jtemp},...
    {'MomentArms','MuscleForce'},{'JointTorque'});

% Function for hip adduction
nMus = length(mai(2).mus.l);
dM = SX.sym('dM',nMus);
Fmus = SX.sym('Fmus',nMus);
Jtemp = 0;
for i=1:length(dM)
    Jtemp = Jtemp + dM(i,1)*Fmus(i,1);
end
f_THipAdd= Function('f_THipAdd',{dM,Fmus},{Jtemp},...
    {'MomentArms','MuscleForce'},{'JointTorque'});

% Function for hip rotation
nMus = length(mai(3).mus.l);
dM = SX.sym('dM',nMus);
Fmus = SX.sym('Fmus',nMus);
Jtemp = 0;
for i=1:length(dM)
    Jtemp = Jtemp + dM(i,1)*Fmus(i,1);
end
f_THipRot= Function('f_THipRot',{dM,Fmus},{Jtemp},...
    {'MomentArms','MuscleForce'},{'JointTorque'});

% Function for knee angle
nMus = length(mai(4).mus.l);
dM = SX.sym('dM',nMus);
Fmus = SX.sym('Fmus',nMus);
Jtemp = 0;
for i=1:length(dM)
    Jtemp = Jtemp + dM(i,1)*Fmus(i,1);
end
f_TKnee= Function('f_TKnee',{dM,Fmus},{Jtemp},...
    {'MomentArms','MuscleForce'},{'JointTorque'});

% Function for ankle angle
nMus = length(mai(5).mus.l);
dM = SX.sym('dM',nMus);
Fmus = SX.sym('Fmus',nMus);
Jtemp = 0;
for i=1:length(dM)
    Jtemp = Jtemp + dM(i,1)*Fmus(i,1);
end
f_TAnkle= Function('f_TAnkle',{dM,Fmus},{Jtemp},...
    {'MomentArms','MuscleForce'},{'JointTorque'});

% Function for subtalar
nMus = length(mai(6).mus.l);
dM = SX.sym('dM',nMus);
Fmus = SX.sym('Fmus',nMus);
Jtemp = 0;
for i=1:length(dM)
    Jtemp = Jtemp + dM(i,1)*Fmus(i,1);
end
f_TSubt= Function('f_TSubt',{dM,Fmus},{Jtemp},...
    {'MomentArms','MuscleForce'},{'JointTorque'});




%% Arm activation dynamics
e_a = SX.sym('e_a',nq.arms); % arm excitations
a_a = SX.sym('a_a',nq.arms); % arm activations
dadt = ArmActivationDynamics(e_a,a_a);
f_ArmActivationDynamics = ...
    Function('f_ArmActivationDynamics',{e_a,a_a},{dadt},...
    {'e','a'},{'dadt'});

%% Lumbar activation dynamics
e_a = SX.sym('e_a',nq.trunk); % arm excitations
a_a = SX.sym('a_a',nq.trunk); % arm activations
dadt = TrunkActivationDynamics(e_a,a_a);
f_TrunkActivationDynamics = ...
    Function('f_TrunkActivationDynamics',{e_a,a_a},{dadt},...
    {'e','a'},{'dadt'});

%% Mtp activation dynamics
e_mtp = SX.sym('e_mtp',nq.mtp); % mtp excitations
a_mtp = SX.sym('a_mtp',nq.mtp); % mtp activations
dmtpdt = ArmActivationDynamics(e_mtp,a_mtp);
f_MtpActivationDynamics = ...
    Function('f_MtpActivationDynamics',{e_mtp,a_mtp},{dmtpdt},...
    {'e','a'},{'dadt'});

%% Muscle contraction dynamics
% Function for Hill-equilibrium
FTtilde     = SX.sym('FTtilde',NMuscle); % Normalized tendon forces
a           = SX.sym('a',NMuscle); % Muscle activations
dFTtilde    = SX.sym('dFTtilde',NMuscle); % Time derivative tendon forces
lMT         = SX.sym('lMT',NMuscle); % Muscle-tendon lengths
vMT         = SX.sym('vMT',NMuscle); % Muscle-tendon velocities
tension_SX  = SX.sym('tension',NMuscle); % Tensions
% atendon_SX  = SX.sym('atendon',NMuscle); % Tendon stiffness
% shift_SX    = SX.sym('shift',NMuscle); % shift curve
Hilldiff    = SX(NMuscle,1); % Hill-equilibrium
FT          = SX(NMuscle,1); % Tendon forces
Fce         = SX(NMuscle,1); % Contractile element forces
Fiso        = SX(NMuscle,1); % Normalized forces from force-length curve
vMmax       = SX(NMuscle,1); % Maximum contraction velocities
massM       = SX(NMuscle,1); % Muscle mass
Fpass       = SX(NMuscle,1); % Passive element forces
% Parameters of force-length-velocity curves
load Fvparam
load Fpparam
load Faparam
for m = 1:NMuscle
    [Hilldiff(m),FT(m),Fce(m),Fpass(m),Fiso(m),vMmax(m),massM(m)] = ...
        ForceEquilibrium_FtildeState_all_tendon(a(m),FTtilde(m),...
        dFTtilde(m),lMT(m),vMT(m),MTparameters_m(:,m),Fvparam,Fpparam,...
        Faparam,tension_SX(m),aTendon(m),shift(m));
end
f_forceEquilibrium_FtildeState_all_tendon = ...
    Function('f_forceEquilibrium_FtildeState_all_tendon',{a,FTtilde,...
    dFTtilde,lMT,vMT,tension_SX},{Hilldiff,FT,Fce,Fpass,Fiso,vMmax,massM},...
    {'a','FTtilde','dFTtilde','lMT','vMT','tension_SX'},...
    {'Hilldiff','FT','Fce','Fpass','Fiso','vMmax','massM'});

% Function to get (normalized) muscle fiber lengths
lM      = SX(NMuscle,1);
lMtilde = SX(NMuscle,1);
for m = 1:NMuscle
    [lM(m),lMtilde(m)] = FiberLength_TendonForce_tendon(FTtilde(m),...
        MTparameters_m(:,m),lMT(m),aTendon(m),shift(m));
end
f_FiberLength_TendonForce_tendon = Function(...
    'f_FiberLength_Ftilde_tendon',{FTtilde,lMT},{lM,lMtilde},...
    {'FTtilde','lMT'},{'lM','lMtilde'});

% Function to get (normalized) muscle fiber velocities
vM      = SX(NMuscle,1);
vMtilde = SX(NMuscle,1);
for m = 1:NMuscle
    [vM(m),vMtilde(m)] = FiberVelocity_TendonForce_tendon(FTtilde(m),...
        dFTtilde(m),MTparameters_m(:,m),lMT(m),vMT(m),aTendon(m),shift(m));
end
f_FiberVelocity_TendonForce_tendon = Function(...
    'f_FiberVelocity_Ftilde_tendon',{FTtilde,dFTtilde,lMT,vMT},...
    {vM,vMtilde},{'FTtilde','dFTtilde','lMT','vMT'},{'vM','vMtilde'});


%% Passive joint torques (bushing forces/ coodinate limit forces)
K_pass      = SX.sym('K_pass',4);
theta_pass  = SX.sym('theta_pass',2);
qin_pass    = SX.sym('qin_pass',1);
qdotin_pass = SX.sym('qdotin_pass',1);
% theta_pass 1 and 2 are inverted on purpose.
Tau_pass = K_pass(1,1)*exp(K_pass(2,1)*(qin_pass-theta_pass(2,1))) + ...
    K_pass(3,1)*exp(K_pass(4,1)*(qin_pass-theta_pass(1,1))) ...
    - 0.1*qdotin_pass;
f_PassiveMoments = Function('f_PassiveMoments',{K_pass,theta_pass,...
    qin_pass,qdotin_pass},{Tau_pass},{'K_pass','theta_pass',...
    'qin_pass','qdotin_pass'},{'Tau_pass'});

%% Passive torque actuated joint torques (linear stiffnes and damping in joints)
stiff	= SX.sym('stiff',1);
damp	= SX.sym('damp',1);
qin     = SX.sym('qin_pass',1);
qdotin  = SX.sym('qdotin_pass',1);
passTATorques = -stiff * qin - damp * qdotin;
f_passiveTATorques = Function('f_passiveTATorques',{stiff,damp,qin,qdotin}, ...
    {passTATorques},{'stiff','damp','qin','qdotin'},{'passTATorques'});

%% Metabolic energy models
act_SX          = SX.sym('act_SX',NMuscle,1); % Muscle activations
exc_SX          = SX.sym('exc_SX',NMuscle,1); % Muscle excitations
lMtilde_SX      = SX.sym('lMtilde_SX',NMuscle,1); % N muscle fiber lengths
vMtilde_SX      = SX.sym('vMtilde_SX',NMuscle,1); % N muscle fiber vel
vM_SX           = SX.sym('vM_SX',NMuscle,1); % Muscle fiber velocities
Fce_SX          = SX.sym('FT_SX',NMuscle,1); % Contractile element forces
Fpass_SX        = SX.sym('FT_SX',NMuscle,1); % Passive element forces
Fiso_SX         = SX.sym('Fiso_SX',NMuscle,1); % N forces (F-L curve)
musclemass_SX   = SX.sym('musclemass_SX',NMuscle,1); % Muscle mass
vcemax_SX       = SX.sym('vcemax_SX',NMuscle,1); % Max contraction vel
pctst_SX        = SX.sym('pctst_SX',NMuscle,1); % Slow twitch ratio
Fmax_SX         = SX.sym('Fmax_SX',NMuscle,1); % Max iso forces
modelmass_SX    = SX.sym('modelmass_SX',1); % Model mass
b_SX            = SX.sym('b_SX',1); % Parameter determining tanh smoothness
% Bhargava et al. (2004)
[energy_total_sm_SX,Adot_sm_SX,Mdot_sm_SX,Sdot_sm_SX,Wdot_sm_SX,...
    energy_model_sm_SX] = getMetabolicEnergySmooth2004all(exc_SX,act_SX,...
    lMtilde_SX,vM_SX,Fce_SX,Fpass_SX,musclemass_SX,pctst_SX,Fiso_SX,...
    MTparameters_m(1,:)',modelmass_SX,b_SX);
fgetMetabolicEnergySmooth2004all = ...
    Function('fgetMetabolicEnergySmooth2004all',...
    {exc_SX,act_SX,lMtilde_SX,vM_SX,Fce_SX,Fpass_SX,musclemass_SX,...
    pctst_SX,Fiso_SX,modelmass_SX,b_SX},{energy_total_sm_SX,...
    Adot_sm_SX,Mdot_sm_SX,Sdot_sm_SX,Wdot_sm_SX,energy_model_sm_SX});

%% get scaling (based on experimental data)

% % We extract experimental data to set bounds and initial guesses if needed
% pathData = [pathRepo,'/OpenSimModel/',subject];
% joints = {'pelvis_tilt','pelvis_list','pelvis_rotation','pelvis_tx',...
%     'pelvis_ty','pelvis_tz','hip_flexion_l','hip_adduction_l',...
%     'hip_rotation_l','hip_flexion_r','hip_adduction_r','hip_rotation_r',...
%     'knee_angle_l','knee_angle_r','ankle_angle_l','ankle_angle_r',...
%     'subtalar_angle_l','subtalar_angle_r','mtp_angle_l','mtp_angle_r',...
%     'lumbar_extension','lumbar_bending','lumbar_rotation','arm_flex_l',...
%     'arm_add_l','arm_rot_l','arm_flex_r','arm_add_r','arm_rot_r',...
%     'elbow_flex_l','elbow_flex_r'};
% pathVariousFunctions = [pathRepo,'/VariousFunctions'];
% addpath(genpath(pathVariousFunctions));
% % Extract joint positions from average walking motion
% motion_walk         = 'walking';
% nametrial_walk.id   = ['average_',motion_walk,'_HGC_mtp'];
% nametrial_walk.IK   = ['IK_',nametrial_walk.id];
% pathIK_walk         = [pathData,'/IK/',nametrial_walk.IK,'.mat'];
% Qs_walk             = getIK(pathIK_walk,joints);


%% Index helpers

% indexes to select kinematics left and right leg
IndexLeft = [jointi.hip_flex.l jointi.hip_add.l jointi.hip_rot.l, ...
    jointi.knee.l jointi.ankle.l jointi.subt.l jointi.mtp.l,...
    jointi.trunk.ext, jointi.trunk.ben, jointi.trunk.rot];
IndexRight = [jointi.hip_flex.r jointi.hip_add.r jointi.hip_rot.r, ...
    jointi.knee.r jointi.ankle.r jointi.subt.r jointi.mtp.r,...
    jointi.trunk.ext, jointi.trunk.ben, jointi.trunk.rot];

%% Passive joint torques
% We extract the parameters for the passive torques of the lower limbs and
% the trunk
pathPassiveMoments = [pathRepo,'/PassiveMoments'];
addpath(genpath(pathPassiveMoments));

k_pass.hip.flex = [-2.44 5.05 1.51 -21.88]';
theta.pass.hip.flex = [-0.6981 1.81]';
k_pass.hip.add = [-0.03 14.94 0.03 -14.94]';
theta.pass.hip.add = [-0.5 0.5]';
k_pass.hip.rot = [-0.03 14.94 0.03 -14.94]';
theta.pass.hip.rot = [-0.92 0.92]';
k_pass.knee = [-6.09 33.94 11.03 -11.33]';
theta.pass.knee = [-2.4 0.13]';
k_pass.ankle = [-2.03 38.11 0.18 -12.12]';
theta.pass.ankle = [-0.74 0.52]';
k_pass.subt = [-60.21 16.32 60.21 -16.32]';
theta.pass.subt = [-0.65 0.65]';
k_pass.mtp = [-0.9 14.87 0.18 -70.08]';
theta.pass.mtp = [0 65/180*pi]';
k_pass.trunk.ext = [-0.35 30.72 0.25 -20.36]';
theta.pass.trunk.ext = [-0.5235987755982988 0.17]';
k_pass.trunk.ben = [-0.25 20.36 0.25 -20.36]';
theta.pass.trunk.ben = [-0.3490658503988659 0.3490658503988659]';
k_pass.trunk.rot = [-0.25 20.36 0.25 -20.36]';
theta.pass.trunk.rot = [-0.3490658503988659 0.3490658503988659]';


%% Create function to compue passive moments

Q_SX =  SX.sym('Q_SX',nq.all,1); % Muscle activations
Qdot_SX = SX.sym('Q_SX',nq.all,1); % Muscle activations


% Get passive joint torques
Tau_passj.hip.flex.l    = f_PassiveMoments(k_pass.hip.flex,...
    theta.pass.hip.flex,Q_SX(jointi.hip_flex.l),...
    Qdot_SX(jointi.hip_flex.l));
Tau_passj.hip.flex.r    = f_PassiveMoments(k_pass.hip.flex,...
    theta.pass.hip.flex,Q_SX(jointi.hip_flex.r),...
    Qdot_SX(jointi.hip_flex.r));
Tau_passj.hip.add.l     = f_PassiveMoments(k_pass.hip.add,...
    theta.pass.hip.add,Q_SX(jointi.hip_add.l),...
    Qdot_SX(jointi.hip_add.l));
Tau_passj.hip.add.r     = f_PassiveMoments(k_pass.hip.add,...
    theta.pass.hip.add,Q_SX(jointi.hip_add.r),...
    Qdot_SX(jointi.hip_add.r));
Tau_passj.hip.rot.l     = f_PassiveMoments(k_pass.hip.rot,...
    theta.pass.hip.rot,Q_SX(jointi.hip_rot.l),...
    Qdot_SX(jointi.hip_rot.l));
Tau_passj.hip.rot.r     = f_PassiveMoments(k_pass.hip.rot,...
    theta.pass.hip.rot,Q_SX(jointi.hip_rot.r),...
    Qdot_SX(jointi.hip_rot.r));
Tau_passj.knee.l        = f_PassiveMoments(k_pass.knee,...
    theta.pass.knee,Q_SX(jointi.knee.l),...
    Qdot_SX(jointi.knee.l));
Tau_passj.knee.r        = f_PassiveMoments(k_pass.knee,...
    theta.pass.knee,Q_SX(jointi.knee.r),...
    Qdot_SX(jointi.knee.r));
Tau_passj.ankle.l       = f_PassiveMoments(k_pass.ankle,...
    theta.pass.ankle,Q_SX(jointi.ankle.l),...
    Qdot_SX(jointi.ankle.l));
Tau_passj.ankle.r       = f_PassiveMoments(k_pass.ankle,...
    theta.pass.ankle,Q_SX(jointi.ankle.r),...
    Qdot_SX(jointi.ankle.r));
Tau_passj.subt.l       = f_PassiveMoments(k_pass.subt,...
    theta.pass.subt,Q_SX(jointi.subt.l),...
    Qdot_SX(jointi.subt.l));
Tau_passj.subt.r       = f_PassiveMoments(k_pass.subt,...
    theta.pass.subt,Q_SX(jointi.subt.r),...
    Qdot_SX(jointi.subt.r));
Tau_passj.trunk.ext     = f_PassiveMoments(k_pass.trunk.ext,...
    theta.pass.trunk.ext,Q_SX(jointi.trunk.ext),...
    Qdot_SX(jointi.trunk.ext));
Tau_passj.trunk.ben     = f_PassiveMoments(k_pass.trunk.ben,...
    theta.pass.trunk.ben,Q_SX(jointi.trunk.ben),...
    Qdot_SX(jointi.trunk.ben));
Tau_passj.trunk.rot     = f_PassiveMoments(k_pass.trunk.rot,...
    theta.pass.trunk.rot,Q_SX(jointi.trunk.rot),...
    Qdot_SX(jointi.trunk.rot));

Tau_passj.sh_flex.l = f_passiveTATorques(stiffnessArm, dampingArm, ...
    Q_SX(jointi.sh_flex.l), Qdot_SX(jointi.sh_flex.l));
Tau_passj.sh_add.l = f_passiveTATorques(stiffnessArm, dampingArm, ...
    Q_SX(jointi.sh_add.l), Qdot_SX(jointi.sh_add.l));
Tau_passj.sh_rot.l = f_passiveTATorques(stiffnessArm, dampingArm, ...
    Q_SX(jointi.sh_rot.l), Qdot_SX(jointi.sh_rot.l));
Tau_passj.sh_flex.r = f_passiveTATorques(stiffnessArm, dampingArm, ...
    Q_SX(jointi.sh_flex.r), Qdot_SX(jointi.sh_flex.r));
Tau_passj.sh_add.r = f_passiveTATorques(stiffnessArm, dampingArm, ...
    Q_SX(jointi.sh_add.r), Qdot_SX(jointi.sh_add.r));
Tau_passj.sh_rot.r = f_passiveTATorques(stiffnessArm, dampingArm, ...
    Q_SX(jointi.sh_rot.r), Qdot_SX(jointi.sh_rot.r));
Tau_passj.elb.l = f_passiveTATorques(stiffnessArm, dampingArm, ...
    Q_SX(jointi.elb.l), Qdot_SX(jointi.elb.l));
Tau_passj.elb.r = f_passiveTATorques(stiffnessArm, dampingArm, ...
    Q_SX(jointi.elb.r), Qdot_SX(jointi.elb.r));
Tau_passj.arm = [Tau_passj.sh_flex.l, Tau_passj.sh_add.l, ...
    Tau_passj.sh_rot.l, Tau_passj.sh_flex.r, Tau_passj.sh_add.r, ...
    Tau_passj.sh_rot.r, Tau_passj.elb.l, Tau_passj.elb.r];

Tau_passj.mtp.l = f_passiveTATorques(stiffnessMtp, dampingMtp, ...
    Q_SX(jointi.mtp.l), Qdot_SX(jointi.mtp.l));
Tau_passj.mtp.r = f_passiveTATorques(stiffnessMtp, dampingMtp, ...
    Q_SX(jointi.mtp.r), Qdot_SX(jointi.mtp.r));
Tau_passj.mtp.all = [Tau_passj.mtp.l, Tau_passj.mtp.r];

Tau_passj_all = [Tau_passj.hip.flex.l,Tau_passj.hip.flex.r,...
    Tau_passj.hip.add.l,Tau_passj.hip.add.r,...
    Tau_passj.hip.rot.l,Tau_passj.hip.rot.r,...
    Tau_passj.knee.l,Tau_passj.knee.r,Tau_passj.ankle.l,...
    Tau_passj.ankle.r,Tau_passj.subt.l,Tau_passj.subt.r,...
    Tau_passj.mtp.all,Tau_passj.trunk.ext,Tau_passj.trunk.ben,...
    Tau_passj.trunk.rot,Tau_passj.arm]';

f_AllPassiveTorques = Function('f_AllPassiveTorques',{Q_SX,Qdot_SX}, ...
    {Tau_passj_all},{'Q_SX','Qdot_SX'},{'Tau_passj_all'});

%% save all the casadifunctions

OutPath = fullfile(pwd,S.CasadiFunc_Folders);
if ~isfolder(OutPath)
    mkdir(OutPath);
end

% save functions
% f_coll.save(fullfile(OutPath,'f_coll'));
f_ArmActivationDynamics.save(fullfile(OutPath,'f_ArmActivationDynamics'));
f_FiberLength_TendonForce_tendon.save(fullfile(OutPath,'f_FiberLength_TendonForce_tendon'));
f_FiberVelocity_TendonForce_tendon.save(fullfile(OutPath,'f_FiberVelocity_TendonForce_tendon'));
f_forceEquilibrium_FtildeState_all_tendon.save(fullfile(OutPath,'f_forceEquilibrium_FtildeState_all_tendon'));
f_J2.save(fullfile(OutPath,'f_J2'));
f_TrunkActivationDynamics.save(fullfile(OutPath,'f_TrunkActivationDynamics'));

f_J6.save(fullfile(OutPath,'f_J6'));
f_J30.save(fullfile(OutPath,'f_J30'));
f_J3.save(fullfile(OutPath,'f_J3'));
f_J23.save(fullfile(OutPath,'f_J23'));
f_J25.save(fullfile(OutPath,'f_J25'));
f_J8.save(fullfile(OutPath,'f_J8'));
f_J92.save(fullfile(OutPath,'f_J92'));
f_J80.save(fullfile(OutPath,'f_J80'));
f_J92exp.save(fullfile(OutPath,'f_J92exp'));
f_J80exp.save(fullfile(OutPath,'f_J80exp'));
f_Jnn2.save(fullfile(OutPath,'f_Jnn2'));
f_Jnn3.save(fullfile(OutPath,'f_Jnn3'));
f_lMT_vMT_dM.save(fullfile(OutPath,'f_lMT_vMT_dM'));
f_MtpActivationDynamics.save(fullfile(OutPath,'f_MtpActivationDynamics'));
f_PassiveMoments.save(fullfile(OutPath,'f_PassiveMoments'));
f_passiveTATorques.save(fullfile(OutPath,'f_passiveTATorques'));
f_T12.save(fullfile(OutPath,'f_T12'));
f_T13.save(fullfile(OutPath,'f_T13'));
f_T27.save(fullfile(OutPath,'f_T27'));
f_T6.save(fullfile(OutPath,'f_T6'));
f_AllPassiveTorques.save(fullfile(OutPath,'f_AllPassiveTorques'));
fgetMetabolicEnergySmooth2004all.save(fullfile(OutPath,'fgetMetabolicEnergySmooth2004all'));

f_THipFlex.save(fullfile(OutPath,'f_ThipFlex'));
f_THipAdd.save(fullfile(OutPath,'f_ThipAdd'));
f_THipRot.save(fullfile(OutPath,'f_ThipRot'));
f_TKnee.save(fullfile(OutPath,'f_TKnee'));
f_TAnkle.save(fullfile(OutPath,'f_TAnkle'));
f_TSubt.save(fullfile(OutPath,'f_TSubt'));

%% Function to compute muscle mass
BoolRajagopal = 1;
[MassM] = GetMuscleMass(muscleNames,MTparameters_m,BoolRajagopal);
save(fullfile(OutPath,'MassM.mat'),'MassM');

%% save default setup structure
% save default setup structure to verify this in the main function part
SDefault = S;
save('SDefault.mat','SDefault');