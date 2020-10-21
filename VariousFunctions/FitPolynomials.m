function [] = FitPolynomials(MainPath,ModelName,Modelpath,PolyFolder,Bool_RunMA)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here


%% Settings

% Import the opensim API
import org.opensim.modeling.*

% Output folder for this subject
OutFolder = PolyFolder;
SubjFolder = fullfile(MainPath,'Polynomials',OutFolder);

%% Create dummy motion and run muscle analysis
if Bool_RunMA  
    if strcmp(ModelName,'Rajagopal')
        
        % bounds on the dofs
        Bound_hipflex = [-50 50];
        Bound_hipadd = [-30 30];
        Bound_hiprot = [-30 30];
        Bound_knee = [0 90];
        Bound_ankle = [-30 30];
        Bound_subt = [-30 30];
        Bound_mtp = [-30 10];        
                
        % create the dummy motion
        n=5000; p=7;
        X = lhsdesign(n,p);
        X_scale=[diff(Bound_hipflex) diff(Bound_hipadd ) diff(Bound_hiprot),...
            diff(Bound_knee) diff(Bound_ankle) diff(Bound_subt) diff(Bound_mtp)];
        X_min=[Bound_hipflex(1) Bound_hipadd(1) Bound_hiprot(1) Bound_knee(1),...
            Bound_ankle(1) Bound_subt(1) Bound_mtp(1)];
        Angles=X.*(ones(n,1)*X_scale)+(ones(n,1)*X_min);
        IndexAngles = [7 8 9 10 12 13 14]+1; % +1 because of time vector
        
        % get model coordinates
        m = Model(Modelpath);
        CoordSet = m.getCoordinateSet();
        nc = CoordSet.getSize();
        NamesCoordinates = cell(1,nc);
        for i = 1:nc
            NamesCoordinates{i} = char(CoordSet.get(i-1).getName());
        end
        % construct a file with generalized coordinates
        headers=[{'time'} NamesCoordinates];
        
        % path with dummy motion
        time=(1:n)./100;
        data=zeros(length(time),length(headers));
        data(:,1)=time;
        data(:,IndexAngles) = Angles;   % right leg
        data(:,IndexAngles+8) = Angles; % left leg
        data(:,12) = Angles(:,4)*pi./180;   % right leg: I check this in the visualise and this seems to be right
        data(:,20) = Angles(:,4)*pi./180;   % left leg
        
        pathDummyMotion = fullfile(SubjFolder,'dummy_motion.mot');
        generateMotFile(data,headers,pathDummyMotion);
        
        %Run a muscle analysis on the dummy motion
        MA_path=fullfile(SubjFolder,'MuscleAnalysis');mkdir(MA_path);
        disp('Muscle analysis running....');
        OpenSim_Muscle_Analysis(pathDummyMotion,model_sel,MA_path,[time(1) time(end)]);
        
    elseif strcmp(ModelName,'Gait92')        
        disp('To Do');        
    end    
end

%% Fit polynomial functions
if strcmp(ModelName,'Rajagopal')
    %% Load the dummy motion
    name_dummymotion = '/dummy_motion.mot';
    path_resultsMA = [SubjFolder,'/MuscleAnalysis/'];
    dummy_motion = importdata([SubjFolder,name_dummymotion]);
    % 15 dofs (mtp locked)
    % Order of dofs: hip flex r, hip add r, hip rot r, knee flex r, ankle flex
    % r, hip flex l, hip add l, hip rot l, knee flex l, ankle flex l, lumbar
    % ext, lumbar bend, lumbar rot, subtalar r, subtalar l, mtp_r, mtp_l
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
    [muscle_spanning_joint_INFO,MuscleInfo] = PolynomialFit_mtp(MuscleData);
    save(fullfile(SubjFolder,'MuscleData.mat'),'MuscleData')
    save(fullfile(SubjFolder,'muscle_spanning_joint_INFO.mat'),'muscle_spanning_joint_INFO')
    save(fullfile(SubjFolder,'MuscleInfo.mat'),'MuscleInfo');    
    
elseif strcmp(ModelName,'Gait92')
    disp('To Do');     
end






end

