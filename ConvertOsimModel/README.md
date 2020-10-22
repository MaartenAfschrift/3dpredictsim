## Prepare input for optimization



### 1 Polynomial fitting

The funciton FitPolynomials create a surrogate model, based on polynomial functions, to compute muscle-tendon lengths and moment arms from the joint kinematics. 

- First, we create a sample of joint angles (i.e. dummy motion) and run muscle analysis on this dummy motion to create a training dataset. Note that running the muscle analysis takes about 20 minutes. 
- Second, we fit the polynomials functions and save it in a spefici folder (input argument PolyFolder). You'll have to point to this folder using the settings *S.PolyFolder* when running the optimization

### 2. Create casadi functions

In the next step we read the muscle-tendon parameters from the model, combine it with the polynomial functions and create a casadi function for most of the equations used in the optimization. This includes:

- Equations for metabolic energy
- Equations for muscle dynamics
- Equations for activation dynamaics
- Casadi version of the polynomial functions
- ....

These functions are saved in a specific folder (input argument CasadiFunc_Folders). You'll have to point to this folder using the settings *S.CasadiFunc_Folders* when running the optimization

### 3. Automatically create .dll files

You have to provide a .cpp file that solves inverse dynamics with the current model you are using. Note that creating this .cpp file (with the correct modelling parameters) is still a manual step. The conversion from .cpp to .dll is automized in the function CreateDllFileFromCpp, which you can download here https://github.com/MaartenAfschrift/CreateDll_PredSim

### 4. Run your simulation

You can now run your tracking or predictive simulations when pointing to the correct:

- Folder with polynomial functions: **S.PolyFolder**
- Casadi functions:  **S.CasadiFunc_Folders**
- .dll files including the file used:
  - the optimization: **S.ExternalFunction**
  - the post processing: **S.ExternalFunction2**



Example code on how to run the optimization

```matlab
% .....

% point to the correct folders
S.PolyFolder= 'MyPolynomials'
S.CasadiFunc_Folders = 'MyCasadiFolder'
S.ExternalFunction = 'ID_Rajagopal.cpp'
S.ExternalFunction = 'Analysis_Rajagopal.cpp'

% Use the S.PolyFolder in the function to fit polynomials
FitPolynomials(MainPath,ModelName,ModelPath,S.PolyFolder,Bool_RunMA)

% createcasadi equations (point to casadi folder and polynomial folder)
CreateCasadiFunctions(MainPath, ModelName, ModelPath, S.CasadiFunc_Folders,...
    S.PolyFolder,SettingsCasFunc);

% Run the optimization with two speeds for example:
S.S.v_tgt =  1.25 % 1.25 m/s
S.savename = 'PredSim_Speed_1_25'; 	% output name results
f_PredSim(S);

S.S.v_tgt =  0.5 % 0.5 m/s
S.savename = 'PredSim_Speed_0_50'; % output name results
f_PredSim(S);


```

