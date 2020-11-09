
% Rajagopal model
disp('Rajagopal model:');
osimModel = fullfile(pwd,'Rajagopal2015.osim');
[Names_Raja,params_Raja] = DispMusclesOsimModel(osimModel);

% gait2392 model
disp(' ');
disp('gait9223 model:');
gait23 = fullfile('C:\Users\u0088756\Documents\FWO\Software\ExoSim\SimExo_3D\3dpredictsim\OpenSimModel','subject1_Poggensee_scaled.osim');
[Names_Gait92,params_Gait92] =DispMusclesOsimModel(gait23);


% this doens't work. Almost all names are different
% paramsOut = params_Gait92;
% NamesOut = Names_Gait92;
% % Adapt Force information in gait23 based on rajagopal model
% ct = 1;
% for i =1:length(Names_Gait92)
%     iSel = strcmp(Names_Gait92{i},Names_Raja);
%     if any(iSel)
%         paramsOut(1,i) = params_Raja(1,iSel);
%     else
%         NamesManual{ct}= Names_Gait92{i}; ct= ct+1;
%     end
% end
% DispHeader(NamesManual);

%% manual copy-pasting force of rajagopal muscles


ListCopy = {'glut_med1_r', 'glmed1_r'; ...
    'glut_med2_r', 'glmed2_r'; ...
    'glut_med3_r', 'glmed3_r';...
    'glut_med1_l', 'glmed1_l'; ...
    'glut_med2_l', 'glmed2_l'; ...
    'glut_med3_l', 'glmed3_l';...
    'glut_min1_r', 'glmin1_r'; ...
    'glut_min2_r', 'glmin2_r'; ...
    'glut_min3_r', 'glmin3_r';...
    'glut_min1_l', 'glmin1_l'; ...
    'glut_min2_l', 'glmin2_l'; ...
    'glut_min3_l', 'glmin3_l';...
    'semimem_r','semimem_r';...
    'semiten_r','semiten_r';...
    'bifemlh_r','bflh_r';...
    'bifemsh_r','bfsh_r';...
    'semimem_l','semimem_l';...
    'semiten_l','semiten_l';...
    'bifemlh_l','bflh_l';...
    'bifemsh_l','bfsh_l';...
    'sar_r','sart_r';...
    'add_long_r','addlong_r';...
    'add_brev_r','addbrev_r';...
    'add_mag3_r','addmagDist_r';...
    'add_mag2_r','addmagMid_r';...
    'add_mag1_r','addmagProx_r';...
    'sar_l','sart_l';...
    'add_long_l','addlong_l';...
    'add_brev_l','addbrev_l';...
    'add_mag3_l','addmagDist_l';...
    'add_mag2_l','addmagMid_l';...
    'add_mag1_l','addmagProx_l';...
    'tfl_r','tfl_r';...
    'pect_r','addmagProx_r';...    % note, we have this one two times now...
    'grac_r','grac_r';...
    'pect_l','addmagProx_l';...    % note, we have this one two times now...
    'grac_l','grac_l';...
    'glut_max1_r','glmax1_r';...
    'glut_max2_r','glmax2_r';...
    'glut_max3_r','glmax3_r';...
    'glut_max1_l','glmax1_l';...
    'glut_max2_l','glmax2_l';...
    'glut_max3_l','glmax3_l';...
    'iliacus_r','iliacus_r';...
    'psoas_r','psoas_r';...
    'peri_r','piri_r';...
    'rect_fem_r','recfem_r';...
    'vas_med_r','vasmed_r';...
    'vas_int_r','vasint_r';...
    'vas_lat_r','vaslat_r';...
    'med_gas_r','gasmed_r';...
    'lat_gas_r','gaslat_r';...
    'soleus_r','soleus_r';...
    'tib_post_r','tibpost_r';...
    'flex_dig_r','fdl_r';...
    'flex_hal_r','fhl_r';...
    'tib_ant_r','tibant_r';...
    'per_brev_r','perbrev_r';...
    'per_long_r','perlong_r';...
    'ext_dig_r','edl_r';...
    'ext_hal_r','ehl_r';...
    'iliacus_l','iliacus_l';...
    'psoas_l','psoas_l';...
    'peri_l','piri_l';...
    'rect_fem_l','recfem_l';...
    'vas_med_l','vasmed_l';...
    'vas_int_l','vasint_l';...
    'vas_lat_l','vaslat_l';...
    'med_gas_l','gasmed_l';...
    'lat_gas_l','gaslat_l';...
    'soleus_l','soleus_l';...
    'tib_post_l','tibpost_l';...
    'flex_dig_l','fdl_l';...
    'flex_hal_l','fhl_l';...
    'tib_ant_l','tibant_l';...
    'per_brev_l','perbrev_l';...
    'per_long_l','perlong_l';...
    'ext_dig_l','edl_l';...
    'ext_hal_l','ehl_l';...
    };
paramsOut = params_Gait92;
NamesOut = Names_Gait92;

for i =1:length(ListCopy)
    iGait92 = strcmp(ListCopy{i,1},Names_Gait92);
    iRaja = strcmp(ListCopy{i,2},Names_Raja);
    if any(iGait92) && any(iRaja)
        paramsOut(1,iGait92) = params_Raja(1,iRaja);
    else
        disp(['error in muscle' ListCopy{i,2}]);
    end
end
%% plot figure
figure(); 
bar(paramsOut(1,:)-params_Gait92(1,:));
ylabel('\Delta Fiso');
set(gca,'XTick',1:92);
set(gca,'TickLabelInterpreter','none');
set(gca,'XTickLabel',Names_Gait92);
set(gca,'XTickLabelRotation',80);
delete_box

%% Adapt the opensim model based on these new parameters


import org.opensim.modeling.*
m = Model(gait23);

muscles = m.getMuscles();

for i = 1:muscles.getSize
   muscle = muscles.get(i-1);
   % find muscle in parameter structure
   mName = char(muscle.getName);
   iSel = strcmp(mName,Names_Gait92);
   if any(iSel)
       Fiso = paramsOut(1,iSel);
       muscle.setMaxIsometricForce(Fiso);
   else
       disp(['error with muscle '  mName]);
   end   
end
m.print(fullfile('C:\Users\u0088756\Documents\FWO\Software\ExoSim\SimExo_3D\3dpredictsim\OpenSimModel','subject1_Poggensee_RajaFiso.osim'));

