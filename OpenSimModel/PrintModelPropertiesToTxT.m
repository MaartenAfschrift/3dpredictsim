
%% Extra information related to the model
%-----------------------------------------
clear all; close all; clc;
OutFile = 'Rajagopal_TxtExport.txt';

%% Read info from the model
import org.opensim.modeling.*

% make it a bit easier to adapt models in cpp by create tables in advance

m = Model('Rajagopal2015.osim');
m.initSystem();
% get the names, mass and inertia of the bodies
nb = m.getBodySet.getSize();
BodyMass = nan(nb,1);
BodyCOM = nan(nb,3);
BodyInertia = nan(nb,3);
BodyNames = cell(nb,1);
for i=1:nb
    BodyMass(i) = m.getBodySet.get(i-1).getMass();
    BodyNames{i} = char(m.getBodySet.get(i-1).getName());
    Isel = m.getBodySet.get(i-1).getInertia().getMoments();
    for j=1:3
        BodyInertia(i,j) = Isel.get(j-1);
    end
    COMsel = m.getBodySet.get(i-1).getMassCenter();
    for j=1:3
        BodyCOM(i,j) = COMsel.get(j-1);
    end
end

% get the location in parent and child for the different joints
Joints = m.getJointSet();
nJoints = Joints.getSize();
JointNames = cell(nJoints,1);
LocationInParent = nan(nJoints,3);
LocationInChild = nan(nJoints,3); 
OrientInParent = nan(nJoints,3); 
OrientInChild = nan(nJoints,3); 
ParentNames = cell(nJoints,1);
ChildNames = cell(nJoints,1);
for i=1:nJoints
    Jsel = Joints.get(i-1);
    JointNames{i} = char(Jsel.getName());
    Child = Jsel.getChildFrame();
    ChildFrame = PhysicalOffsetFrame.safeDownCast(Child);
    Child_transl = ChildFrame.get_translation();
    Child_orient = ChildFrame.get_orientation();
    Parent = Jsel.getParentFrame();
    ParentFrame = PhysicalOffsetFrame.safeDownCast(Parent);
    Parent_transl = ParentFrame.get_translation();
    Parent_orient = ParentFrame.get_orientation();
    for j = 1:3
        LocationInChild(i,j) = Child_transl.get(j-1);
        OrientInChild(i,j) = Child_orient.get(j-1);
        LocationInParent(i,j) = Parent_transl.get(j-1);
        OrientInParent(i,j) = Parent_orient.get(j-1);
    end
    % get names of connected bodies
    ParentNames{i} = char(ParentFrame.getSocket('parent').getConnecteeAsObject.getName());
    ChildNames{i} = char(ChildFrame.getSocket('parent').getConnecteeAsObject.getName());
end


% Hard Coded - Joint defenitions
IndCustom = [1:6 8:12 14:17 19:21];
IndWeld = [18 22];
IndPin = [7 13];
JointDef = cell(22,1);
JointDef(IndCustom) = {'CustomJoint'};
JointDef(IndWeld) = {'WeldJoint'};
JointDef(IndPin) = {'PinJoint'};

% Hard coded export order
OrderBodies = [1 8 2 9 3 10 4 11 5 12 6 13 7 14 19 15 20 16 21 17 22 18];
OrderJoints = OrderBodies;


%% Print results to a text file to make the copy - paste a bit easier

fid = fopen(OutFile,'wt');
fprintf( fid, '%s\r\n', 'Export opensim model ');
fprintf( fid, '%s\r\n', ' -- Bodies: -- ');

for i=OrderBodies
    fprintf( fid, '%s', [BodyNames{i} ' = new OpenSim::Body(']);
    fprintf( fid, '%s', ['"' BodyNames{i} '",' ]);
    
    fprintf( fid, '%.4f%s', BodyMass(i), ', Vec3(');    
    fprintf( fid, '%.4f%s', BodyCOM(i,1), ', ');
    fprintf( fid, '%.4f%s', BodyCOM(i,2), ', ');
    fprintf( fid, '%.4f', BodyCOM(i,3));
    
    fprintf( fid, '%s', '), Inertia(');
    fprintf( fid, '%.4f%s', BodyInertia(i,1), ', ');
    fprintf( fid, '%.4f%s', BodyInertia(i,2), ', ');
    fprintf( fid, '%.4f', BodyInertia(i,3));
    
    fprintf( fid, '%s\n', ', 0, 0, 0));');
end

fprintf( fid, '\n\n');

fprintf( fid, '%s\r\n', ' -- Joints: -- ');

for i=OrderJoints
    fprintf( fid, '%s', [JointNames{i} ' = new ' JointDef{i} ' (']);
    fprintf( fid, '%s', ['"' JointNames{i} '", *' ]);
    fprintf( fid, '%s', [ParentNames{j} ', Vec3(']);    
    fprintf( fid, '%.4f%s', LocationInParent(i,1), ', ');
    fprintf( fid, '%.4f%s', LocationInParent(i,2), ', ');
    fprintf( fid, '%.4f%s', LocationInParent(i,3),'), Vec3(');
    fprintf( fid, '%.4f%s', OrientInParent(i,1), ', ');
    fprintf( fid, '%.4f%s', OrientInParent(i,2), ', ');
    fprintf( fid, '%.4f%s', OrientInParent(i,3),'), ');
    fprintf( fid, '%s', ['*' ChildNames{i} ' , Vec3(']);
    fprintf( fid, '%.4f%s', LocationInChild(i,1), ', ');
    fprintf( fid, '%.4f%s', LocationInChild(i,2), ', ');
    fprintf( fid, '%.4f%s', LocationInChild(i,3),'), Vec3(');
    fprintf( fid, '%.4f%s', OrientInChild(i,1), ', ');
    fprintf( fid, '%.4f%s', OrientInChild(i,2), ', ');
    fprintf( fid, '%.4f%s', OrientInChild(i,3), ')');
    if any(IndCustom == i)
        fprintf( fid, '%s\n',[', st_' JointNames{i} ');']); 
    else
        fprintf( fid, '%s\n',');'); 
    end
end

fclose(fid);


