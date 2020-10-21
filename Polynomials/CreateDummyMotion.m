%% Create a Dummy motion
%-----------------------

%% Settings:
InstallPath = 'C:\Users\u0088756\Documents\FWO\Software\ExoSim\SimExo_3D\3dpredictsim';
OutFolder = 'Rajagopal2015';


%% Bounds
% extract parameters from Antoine his files
% d = importdata(fullfile(InstallPath,'Polynomials\subject1\MuscleAnalysis\dummy_motion\dummy_motion_mtp.mot'));
% dat=d.data;
% Bound_hipflex = [min(dat(:,5)) max(dat(:,5))];
% Bound_hipadd = [min(dat(:,6)) max(dat(:,6))];
% Bound_hiprot = [min(dat(:,7)) max(dat(:,7))];
% Bound_knee = [min(dat(:,8)) max(dat(:,8))];
% Bound_ankle = [min(dat(:,9)) max(dat(:,9))];
% Bound_subt = [min(dat(:,18)) max(dat(:,18))];
% Bound_mtp = [min(dat(:,20)) max(dat(:,20))];

Bound_hipflex = [-50 50];
Bound_hipadd = [-30 30];
Bound_hiprot = [-30 30];
Bound_knee = [0 90];
Bound_ankle = [-30 30];
Bound_subt = [-30 30];
Bound_mtp = [-30 10];


%% Running the muscle analysis for a dummy motion spanning the range motion for the degrees of motion

% Samples
n=5000; p=7;
X = lhsdesign(n,p);
X_scale=[diff(Bound_hipflex) diff(Bound_hipadd ) diff(Bound_hiprot) diff(Bound_knee) diff(Bound_ankle) diff(Bound_subt) diff(Bound_mtp)];
X_min=[Bound_hipflex(1) Bound_hipadd(1) Bound_hiprot(1) Bound_knee(1) Bound_ankle(1) Bound_subt(1) Bound_mtp(1)];
Angles=X.*(ones(n,1)*X_scale)+(ones(n,1)*X_min);
IndexAngles = [7 8 9 10 12 13 14]+1; % +1 because of time vector

% get the opensim model
model_sel=fullfile(InstallPath,'OpenSimModel','Rajagopal2015.osim');

% get model coordinates
import org.opensim.modeling.*
m = Model(model_sel);
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
pathDummyMotion = fullfile(InstallPath,'Polynomials',OutFolder,'dummy_motion.mot');
generateMotFile(data,headers,pathDummyMotion);

%Run a muscle analysis on the dummy motion
output_path=fullfile(InstallPath,'Polynomials',OutFolder,'MuscleAnalysis');mkdir(output_path);
OpenSim_Muscle_Analysis(pathDummyMotion,model_sel,output_path,[time(1) time(end)]);
