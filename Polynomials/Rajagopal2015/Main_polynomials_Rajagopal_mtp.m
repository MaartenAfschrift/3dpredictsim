% This function generates polynomials to approximate muscle-tendon lengths
% and moment arms. The code is from Wouter Aerts and is adapted to be
% used with CasADi.
%
% Author: Antoine Falisse
%
% Datum: 03/04/2018
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all
close all
clc

%% User inputs
runPolynomialfit = 1;
savePolynomials = 1;

%% Extract time and angles from dummy motion
subject = 'Rajagopal2015';
pathmain = pwd;
name_dummymotion = '/dummy_motion.mot';
path_dummymotion = pathmain;
path_resultsMA = [pathmain,'/MuscleAnalysis/'];

dummy_motion = importdata([path_dummymotion,name_dummymotion]);
% 15 dofs (mtp locked)
% Order of dofs: hip flex r, hip add r, hip rot r, knee flex r, ankle flex
% r, hip flex l, hip add l, hip rot l, knee flex l, ankle flex l, lumbar
% ext, lumbar bend, lumbar rot, subtalar r, subtalar l, mtp_r, mtp_l
%order_Qs = [5:9,18,20,15:17];
order_Qs = [7 8 9 10 12 13 14]+1;
q = dummy_motion.data(:,order_Qs).*(pi/180);

% adapt the angle the knee such that it's similar to the definition in
% opensim.
q(:,4) = -q(:,4);


%% Import data
% subject pre-fix
SubjPre = 'dummy_motion';
% lMT
lMT = importdata([path_resultsMA,SubjPre '_MuscleAnalysis_Length.sto']);
% hip flexion r
MA.hip.flex = importdata([path_resultsMA,SubjPre '_MuscleAnalysis_MomentArm_hip_flexion_r.sto']);
% hip adduction r
MA.hip.add = importdata([path_resultsMA,SubjPre '_MuscleAnalysis_MomentArm_hip_adduction_r.sto']);
% hip rotation r
MA.hip.rot = importdata([path_resultsMA,SubjPre '_MuscleAnalysis_MomentArm_hip_rotation_r.sto']);
% knee flexion r
MA.knee.flex = importdata([path_resultsMA,SubjPre '_MuscleAnalysis_MomentArm_knee_angle_r.sto']);
% ankle flexion r
MA.ankle.flex = importdata([path_resultsMA,SubjPre '_MuscleAnalysis_MomentArm_ankle_angle_r.sto']);
% subtalar r
MA.sub = importdata([path_resultsMA,SubjPre '_MuscleAnalysis_MomentArm_subtalar_angle_r.sto']);
% mtp r
MA.mtp = importdata([path_resultsMA,SubjPre '_MuscleAnalysis_MomentArm_mtp_angle_r.sto']);

% changes sign moment arms knee joint
MA.knee.flex.data(:,2:end) = -MA.knee.flex.data(:,2:end);

%% Organize MuscleData
if ~isfield(dummy_motion,'colheaders')
    dummy_motion.colheaders = strsplit(dummy_motion.textdata{end});
end
MuscleData.dof_names = dummy_motion.colheaders(order_Qs);
muscleNames = {'addbrev_r','addlong_r','addmagDist_r','addmagIsch_r','addmagMid_r','addmagProx_r',...
    'bflh_r','bfsh_r','edl_r','ehl_r','fdl_r','fhl_r','gaslat_r','gasmed_r','glmax1_r','glmax2_r',...
    'glmax3_r','glmed1_r','glmed2_r','glmed3_r','glmin1_r','glmin2_r','glmin3_r','grac_r','iliacus_r',...
    'perbrev_r','perlong_r','piri_r','psoas_r','recfem_r','sart_r','semimem_r','semiten_r','soleus_r',...
    'tfl_r','tibant_r','tibpost_r','vasint_r','vaslat_r','vasmed_r'};
MuscleData.muscle_names = muscleNames;
for m = 1:length(muscleNames)
    MuscleData.lMT(:,m)     = lMT.data(:,strcmp(lMT.colheaders,muscleNames{m}));            % lMT
    MuscleData.dM(:,m,1)    = MA.hip.flex.data(:,strcmp(lMT.colheaders,muscleNames{m}));    % hip_flex
    MuscleData.dM(:,m,2)    = MA.hip.add.data(:,strcmp(lMT.colheaders,muscleNames{m}));     % hip_add
    MuscleData.dM(:,m,3)    = MA.hip.rot.data(:,strcmp(lMT.colheaders,muscleNames{m}));     % hip_rot
    MuscleData.dM(:,m,4)    = MA.knee.flex.data(:,strcmp(lMT.colheaders,muscleNames{m}));   % knee
    MuscleData.dM(:,m,5)    = MA.ankle.flex.data(:,strcmp(lMT.colheaders,muscleNames{m}));  % ankle
    MuscleData.dM(:,m,6)    = MA.sub.data(:,strcmp(lMT.colheaders,muscleNames{m}));         % sub
    MuscleData.dM(:,m,7)    = MA.mtp.data(:,strcmp(lMT.colheaders,muscleNames{m}));         % mtp
end
MuscleData.q = q;

%% Call PolynomialFit
if runPolynomialfit
    [muscle_spanning_joint_INFO,MuscleInfo] = PolynomialFit_mtp(MuscleData);
    if savePolynomials
        save(['MuscleData_',subject],'MuscleData')
        save(['muscle_spanning_joint_INFO_',subject],'muscle_spanning_joint_INFO')
        save(['MuscleInfo_',subject],'MuscleInfo')
    end
end
