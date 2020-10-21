%% Evaluate reconstruction joint moments with polynomial approximation
%---------------------------------------------------------------------

clear all; clc;
%% settings
Bools.CreateCasFunc = 0;
Bools.ReadMuscleAnalysis = 0;

%% load polynomials

% load results polynomial approximation
load('muscle_spanning_joint_INFO_Rajagopal2015.mat');
load('MuscleInfo_Rajagopal2015.mat');

% load kinematics dummy motion
dummy_motion = importdata('dummy_motion.mot');
order_Qs = [7 8 9 10 12 13 14]+1;
q = dummy_motion.data(:,order_Qs).*(pi/180);

% adapt the angle the knee such that it's similar to the definition in
% opensim.
q(:,4) = -q(:,4);

%% Casadi function to evaluate polynomials
import casadi.*
if Bools.CreateCasFunc
    tic
    muscle_spanning_info_m = muscle_spanning_joint_INFO;
    MuscleInfo_m.muscle    = MuscleInfo.muscle;
    
    qin     = SX.sym('qin',1,7);
    qdotin  = SX.sym('qdotin',1,7);
    lMT     = SX(40,1);
    vMT     = SX(40,1);
    dM      = SX(40,7);
    for i=1:40
        index_dof_crossing  = find(muscle_spanning_info_m(i,:)==1);
        order               = MuscleInfo_m.muscle(i).order;
        [mat,diff_mat_q]    = n_art_mat_3_cas_SX(qin(1,index_dof_crossing),...
            order);
        lMT(i,1)            = mat*MuscleInfo_m.muscle(i).coeff;
        vMT(i,1)            = 0;
        dM(i,1:7)           = 0;
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
    dt = toc;
    disp(['Create casadi function takes ' num2str(dt) ' seconds']);
else
    CasadiFuncFolder = 'C:\Users\u0088756\Documents\FWO\Software\ExoSim\SimExo_3D\3dpredictsim\CasADiFunctions\Casadi_Rajagopal2015';
    f_lMT_vMT_dM    = Function.load(fullfile(CasadiFuncFolder,'f_lMT_vMT_dM'));
end



%% get results muscle analysis
if Bools.ReadMuscleAnalysis
    % subject pre-fix
    SubjPre = 'dummy_motion';
    path_resultsMA = 'C:\Users\u0088756\Documents\FWO\Software\ExoSim\SimExo_3D\3dpredictsim\Polynomials\Rajagopal2015\MuscleAnalysis\';
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
    
    % Organize MuscleData
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
    save('MuscleData.mat','MuscleData');
else
    load('MuscleData_Rajagopal2015.mat','MuscleData');
    q = MuscleData.q;
end

%% Evaluate polynomials
nfr = length(q);
Poly.lMT = zeros(nfr,40);
Poly.vMT = zeros(nfr,40);
Poly.dM  = zeros(nfr,40,7);

tic
for i=1:nfr
    [LMT_temp,VMT_temp,dM_temp] = f_lMT_vMT_dM(q(i,:),zeros(1,7));
    Poly.lMT(i,:) = full(LMT_temp);
    Poly.vMT(i,:) = full(VMT_temp);
    Poly.dM(i,:,:) = full(dM_temp);
end
dt = toc;
disp(['Evaluation polynomials for ' num2str(nfr) ' frames takes ' num2str(dt) ' seconds']);

%% Scatter plot between fit and reconstructed LMT and vMT

muscleNames = MuscleData.muscle_names;
figure();
for m=1:40
    subplot(5,8,m);
    plot(MuscleData.lMT(:,m),Poly.lMT(:,m),'ok','MarkerFaceColor',[0 0 0]);
    title(muscleNames{m})
    if rem(m,8) == 1
        ylabel('Poly');
    end
    if m>4*8
        xlabel('Osim');
    end
    Ax = gca;
    Ax.Box = 'off';
end
%% RMS values muscle-tendon length
RMS_lMT = rms(MuscleData.lMT-Poly.lMT);
R_lMT = corr(MuscleData.lMT,Poly.lMT);
R_lMT = diag(R_lMT);

figure();
subplot(2,1,1)
bar(RMS_lMT*100);
set(gca,'XTick',1:40);
set(gca,'XTickLabel',muscleNames);
set(gca,'XTickLabelRotation',60);
ylabel('RMS_LMT [cm]');
subplot(2,1,2)
bar(R_lMT);
set(gca,'XTick',1:40);
set(gca,'XTickLabel',muscleNames);
set(gca,'XTickLabelRotation',60);
ylabel('R');

%% Moment arm approximation

% compute RMS errors and correlation coefficients
dM_RMS = squeeze(rms(MuscleData.dM-Poly.dM));
figure();
for m=1:40
    subplot(5,8,m);
    bar(dM_RMS(m,:)*100);
    title(muscleNames{m})
    if rem(m,8) == 1
        ylabel('RMS (cm)');
    end
    if m>4*8
        set(gca,'XTick',1:7);
        set(gca,'XTickLabel',{'hip flex','hip add','hip rot','knee','ankle','subt','mtp'});
        set(gca,'XTickLabelRotation',60);
    else
        set(gca,'XTick',[]);
    end
    Ax = gca;
    Ax.Box = 'off';
end
suptitle('Moment arm: RMS values');





