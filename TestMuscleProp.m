%% Test if we read the MT parameters correctly


% test MT properties
New = load('C:\Users\u0088756\Documents\FWO\Software\ExoSim\SimExo_3D\3dpredictsim\CasADiFunctions\s1_Poggensee_FisoRaja\MTparameters.mat');
Old = load('C:\Users\u0088756\Documents\FWO\Software\ExoSim\SimExo_3D\3dpredictsim\MuscleModel\s1_Poggensee\MTparameters_s1_Poggensee_mtp.mat');


DiffMT = New.MTparameters(3,1:46)-Old.MTparameters(3,1:46);
figure(); bar(DiffMT);

% test muscle-tendon length

import casadi.*
PathDefaultFunc = 'C:\Users\u0088756\Documents\FWO\Software\ExoSim\SimExo_3D\3dpredictsim\CasADiFunctions\s1_Poggensee_FisoRaja';
f_lMT_vMT_dM_New = Function.load(fullfile(PathDefaultFunc,'f_lMT_vMT_dM'));
PathDefaultFunc = 'C:\Users\u0088756\Documents\FWO\Software\ExoSim\SimExo_3D\3dpredictsim\CasADiFunctions\Casadi_s1Pog_mtp';
f_lMT_vMT_dM_Old = Function.load(fullfile(PathDefaultFunc,'f_lMT_vMT_dM'));

q = -rand(1,10);
qd = -rand(1,10);

[LMT1,vMT1,dM1] = f_lMT_vMT_dM_New(q,qd);
[LMT2,vMT2,dM2] = f_lMT_vMT_dM_Old(q,qd);


dLMT = full(LMT1)-full(LMT2);
dVMT = full(vMT1)-full(vMT2);
dM = full(dM1)-full(dM2);
%%
max(abs(diff(dLMT)))
max(abs(diff(dVMT)))
max(abs(diff(dM)))