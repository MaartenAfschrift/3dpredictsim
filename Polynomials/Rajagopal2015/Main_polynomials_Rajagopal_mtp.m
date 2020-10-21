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
% 
% %% Create CasADi functions
% import casadi.*
% load(['muscle_spanning_joint_INFO_',subject])
% load(['MuscleInfo_',subject])
% NMuscle = length(MuscleInfo.muscle);
% q_leg_trunk = length(order_Qs);
% qin     = SX.sym('qin',1,q_leg_trunk);
% qdotin  = SX.sym('qdotin',1,q_leg_trunk);
% lMT     = SX(NMuscle,1);
% vMT     = SX(NMuscle,1);
% dM      = SX(NMuscle,q_leg_trunk);
% for i=1:NMuscle
%     index_dof_crossing  = find(muscle_spanning_joint_INFO(i,:)==1);
%     order               = MuscleInfo.muscle(i).order;
%     [mat,diff_mat_q]    = n_art_mat_3_cas_SX(qin(1,index_dof_crossing),order);
%     lMT(i,1)            = mat*MuscleInfo.muscle(i).coeff;
%     vMT(i,1)            = 0;
%     dM(i,1:q_leg_trunk) = 0;
%     nr_dof_crossing     = length(index_dof_crossing);
%     for dof_nr = 1:nr_dof_crossing
%         dM(i,index_dof_crossing(dof_nr)) = (-(diff_mat_q(:,dof_nr)))'*MuscleInfo.muscle(i).coeff;
%         vMT(i,1) = vMT(i,1) + (-dM(i,index_dof_crossing(dof_nr))*qdotin(1,index_dof_crossing(dof_nr)));
%     end
% end
% f_lMT_vMT_dM = Function('f_lMT_vMT_dM',{qin,qdotin},{lMT,vMT,dM});
% 
% %% Check results
% % load(['MuscleData_',subject])
% lMT_out_r = zeros(size(q,1),NMuscle);
% vMT_out_r = zeros(size(q,1),NMuscle);
% dM_out_r = zeros(size(q,1),NMuscle,q_leg_trunk);
% for i = 1:size(q,1)
%     [out1_r,out2_r,out3_r] = f_lMT_vMT_dM(MuscleData.q(i,:),0);
%     lMT_out_r(i,:) = full(out1_r);
%     vMT_out_r(i,:) = full(out2_r);
%     dM_out_r(i,:,1) = full(out3_r(:,1));
%     dM_out_r(i,:,2) = full(out3_r(:,2));
%     dM_out_r(i,:,3) = full(out3_r(:,3));
%     dM_out_r(i,:,4) = full(out3_r(:,4));
%     dM_out_r(i,:,5) = full(out3_r(:,5));
%     dM_out_r(i,:,6) = full(out3_r(:,6));
%     dM_out_r(i,:,7) = full(out3_r(:,7));
% %     dM_out_r(i,:,8) = full(out3_r(:,8));
% %     dM_out_r(i,:,9) = full(out3_r(:,9));
% %     dM_out_r(i,:,10) = full(out3_r(:,10));
% end
% 
% 
% %% Assert results
% for i = 1:NMuscle
%     assertLMT(:,i) = abs(lMT_out_r(:,i) - MuscleData.lMT(:,i));
%     assertdM.hip.flex(:,i) = abs(dM_out_r(:,i,1) - MuscleData.dM(:,i,1));
%     assertdM.hip.add(:,i) = abs(dM_out_r(:,i,2) - MuscleData.dM(:,i,2));
%     assertdM.hip.rot(:,i) = abs(dM_out_r(:,i,3) - MuscleData.dM(:,i,3));
%     assertdM.knee(:,i) = abs(dM_out_r(:,i,4) - MuscleData.dM(:,i,4));
%     assertdM.ankle(:,i) = abs(dM_out_r(:,i,5) - MuscleData.dM(:,i,5));
%     assertdM.sub(:,i) = abs(dM_out_r(:,i,6) - MuscleData.dM(:,i,6));
%     assertdM.mtp(:,i) = abs(dM_out_r(:,i,7) - MuscleData.dM(:,i,7));
% %     assertdM.lumb.ext(:,i) = abs(dM_out_r(:,i,8) - MuscleData.dM(:,i,8));
% %     assertdM.lumb.bend(:,i) = abs(dM_out_r(:,i,9) - MuscleData.dM(:,i,9));
% %     assertdM.lumb.rot(:,i) = abs(dM_out_r(:,i,10) - MuscleData.dM(:,i,10));
% end
% assertLMTmax_r = max(max(assertLMT));
% assertdM.hip.flexmax = max(max(assertdM.hip.flex));
% assertdM.hip.addmax = max(max(assertdM.hip.add));
% assertdM.hip.rotmax = max(max(assertdM.hip.rot));
% assertdM.kneemax = max(max(assertdM.knee));
% assertdM.anklemax = max(max(assertdM.ankle));
% assertdM.submax = max(max(assertdM.sub));
% assertdM.mtpmax = max(max(assertdM.mtp));
% % assertdM.lumb.extmax = max(max(assertdM.lumb.ext));
% % assertdM.lumb.bendmax = max(max(assertdM.lumb.bend));
% % assertdM.lumb.rotmax = max(max(assertdM.lumb.rot));
