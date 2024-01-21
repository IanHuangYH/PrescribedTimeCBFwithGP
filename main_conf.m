clc;close all;clear;

%% System Parameters
SystemParam = SystemParamInitialization();

%% Initial conditions
TrajFlag = 1; %1:safe -> safe, 2: unsafe -> safe
dt = 0.001;
totalTime = 6;
[q_desired, time, ~] = jointTrajGenerateWithDiffInitialCase(totalTime, dt, TrajFlag);
q = [q_desired(1,1); q_desired(2,1)];

q_dot = [0; 0];
TimeLen = length(q_desired);
base_pos = [0;0];

%% total result initialize
result = ResultInitialization(SystemParam.dof, TimeLen);
% normal loop
result.tor_org = GetNormalWithoutPreCBF(TimeLen, q_desired, q, q_dot, SystemParam,dt);

%% GP off line learning
dof = size(q,1);
MaxDataNum = 900;
LocalGP = OfflineTrainGP(dof, MaxDataNum);

%% PreCBFGP initialization
PrescibedTime = 4;
LocalPreCBFGP = PreCBFGP_2LinkManipulator(PrescibedTime, SystemParam, LocalGP);

%% Main control loop
q = [q_desired(1,1); q_desired(2,1)];
q_dot = [0; 0];
t0 = 0;
PrescribedTimeFlag = 1; % 1: preCBF, 0: without PreCBF
UncertaintyFlag = 3; %1: no uncentainty, no GP, 2: uncentainty, no GP, 3: uncentainty and GP, 4: uncetainty and uncertainty function

for i = 1:TimeLen
    [u_norm, error] = PDController(q_desired(:,i), q, q_dot, SystemParam);
    % Prescribed time CBF
    [u_safe, Nom_M ,Nom_C, Nom_G,result.a_coe_org_paper(:,i),result.a_coe_withUncertainty(:,i),result.a_coe_withGP_paper(:,i),result.b_coe_paper(:,:,i), result.errorbound(1,i)] = ...
        LocalPreCBFGP.ComputeSafeU(u_norm,q,q_dot,t0,time(i),UncertaintyFlag);
    

    % input to real system
    if (PrescribedTimeFlag == 0)
        [q, q_dot] = dynamicSystem(u_norm, q, q_dot,SystemParam,dt);
    else %flag = 1
        [q, q_dot] = dynamicSystem(u_safe, q, q_dot, SystemParam,dt);
    end

    % record result
    result.q_r(:,i) = q;
    result.qdot_r(:,i) = q_dot;
    result.tor_r(:,i) = u_norm;
    result.torsafe_r(:,i) = u_safe;
    result.q_error_r(:,i)=error;
    result.end_effector_pos_cmd(:,i) = forwardKinematics(SystemParam, q_desired(:,i));
    result.end_effector_pos_r(:,i) = forwardKinematics(SystemParam, q_desired(:,i));
    result.CBFCon_with_uncertainty(:,i) = result.a_coe_withUncertainty(:,i) + result.b_coe_paper(:,:,i)*u_safe;
    result.CBFCon_with_GP(:,i) = result.a_coe_withGP_paper(:,i) + result.b_coe_paper(:,:,i)*u_safe;
end

%% plot result
%joint pos
figure()
subplot(2,1,1)
plot(time, q_desired(1,:), time, result.q_r(1,:),'LineWidth',2);
xlabel( 'time(sec)' ); ylabel( 'joint pos(rad)' ); legend( 'cmd', 'feedback' ); grid on; title('1st joint position');

subplot(2,1,2)
plot(time, q_desired(2,:), time, result.q_r(2,:),'LineWidth',2);
xlabel( 'time(sec)' ); ylabel( 'joint pos(rad)' ); legend( 'cmd', 'feedback' ); grid on; title('2nd joint position');

% joint space plot
if TrajFlag == 1
figure()
plot3(result.q_r(1,:), result.q_r(2,:), time,q_desired(1,:),q_desired(2,:),time,'LineWidth',2);
elseif TrajFlag == 2
figure()
timeNum = PrescibedTime/dt + 1;
plot3(result.q_r(1,1:timeNum), result.q_r(2,1:timeNum), time(1:timeNum),q_desired(1,1:timeNum),q_desired(2,1:timeNum),time(1:timeNum),'LineWidth',2);
end
legend('CBF','org tra');
view(0,90)
hold on
% Define the range for plotting (adjust as needed)
x_range = linspace(0, pi/2, 400);

% Open a new figure
% Plotting x = pi/2
line([pi/2 pi/2], [-pi/2,pi/2], 'Color', 'r', 'LineStyle', '--');

% Plotting x = 0
line([0 0], [-pi/2,pi/2], 'Color', 'g', 'LineStyle', '--');

% Plotting x + y = 0 (y = -x)
y = -x_range;
plot(x_range, y, 'b--');

% Plotting x + y = pi/2 (y = pi/2 - x)
y = pi/2 - x_range;
plot(x_range, y, 'm--');
xlabel( 'q1' ); ylabel( 'q2' ); grid on; title('joint space');


%% debug code
figure()
subplot(2,1,1)
plot(time,result.a_coe_org_paper(1,:),time,result.a_coe_withUncertainty(1,:),time,result.a_coe_withGP_paper(1,:),'LineWidth',2)
xlabel( 'time(sec)' ); ylabel( 'acoe' ); legend( 'org', 'uncetainty','AfterGP' ); grid on; title('a coe');
xlim([0,1.5])

subplot(2,1,2)
b_coe1 = squeeze(result.b_coe_paper(1,:,:));
plot(time,b_coe1(1,:),time,b_coe1(2,:),'LineWidth',2)
xlabel( 'time(sec)' ); ylabel( 'bcoe' ); legend( 'b1', 'b2' ); grid on; title('b coe');
xlim([0,1.5])

figure()
plot(time,result.CBFCon_with_uncertainty(1,:),time,result.CBFCon_with_GP(1,:),'LineWidth',2)
xlabel( 'time(sec)' ); ylabel( 'CBF_constraint' ); legend( 'uncertainty', 'GP error bound' ); grid on; title('a coe');
xlim([0,1.5])

figure()
plot(time,result.CBFCon_with_uncertainty(1,:) - result.CBFCon_with_GP(1,:), time, result.errorbound,'LineWidth',2)
xlabel( 'time(sec)' ); ylabel( 'error of CBF_constraint' ); grid on; title('check CBF constraint');
xlim([0,1.5]); legend('CBFUncen-CBFGP','errorbound');

% %joint torque and safe torque
% figure()
% subplot(2,1,1)
% plot(time, result.tor_r(1,:), time, result.torsafe_r(1,:), 'LineWidth',2);
% xlabel( 'time(sec)' ); ylabel( 'joint torque(N.m)' ); legend( 'torOrg', 'torSafe' );grid on; title('1st joint torque');
% xlim([0,1.5])
% 
% subplot(2,1,2)
% plot(time, result.tor_r(2,:),time, result.torsafe_r(2,:),'LineWidth',2);
% xlabel( 'time(sec)' ); ylabel( 'joint torque(N.m)' ); legend( 'torNom', 'torSafe' );grid on; title('2nd joint torque');
% xlim([0,1.5])
% 
% %normal torque and safe torque
% figure()
% subplot(2,1,1)
% plot(time, result.tor_org(1,:),'LineWidth',2);
% xlabel( 'time(sec)' ); ylabel( 'joint torque(N.m)' ); grid on; title('1st joint org torque');
% 
% subplot(2,1,2)
% plot(time, result.tor_org(2,:),'LineWidth',2);
% xlabel( 'time(sec)' ); ylabel( 'joint torque(N.m)' ); grid on; title('2nd joint org torque');
% 
% %cartesain pos
% figure(4)
% plot3(result.end_effector_pos_cmd(1,:), result.end_effector_pos_cmd(2,:), time, result.end_effector_pos_r(1,:), result.end_effector_pos_r(2,:),time,'LineWidth',2);
% xlabel( 'xpos(m)' ); ylabel( 'ypos(m)' ); legend( 'cmd', 'feedback' ); grid on; title('planar eff position');
% view(0,90);
% 
% figure(5)
% subplot(2,1,1)
% plot(time, result.end_effector_pos_cmd(1,:), time, result.end_effector_pos_r(1,:),'LineWidth',2);
% xlabel( 'time(sec)' ); ylabel( 'pos(m)' ); legend( 'cmd', 'feedback' ); grid on; title('1st x position');
% 
% subplot(2,1,2)
% plot(time, result.end_effector_pos_cmd(2,:), time, result.end_effector_pos_r(2,:),'LineWidth',2);
% xlabel( 'time(sec)' ); ylabel( 'pos(m)' ); legend( 'cmd', 'feedback' ); grid on; title('2nd y position');
% 
% %joint vel
% figure(6)
% subplot(2,1,1)
% plot(time, result.qdot_r(1,:),'LineWidth',2);
% xlabel( 'time(sec)' ); ylabel( 'joint vel(rad/s)' ); grid on; title('1st joint velocity');
% 
% subplot(2,1,2)
% plot(time, result.qdot_r(2,:),'LineWidth',2);
% xlabel( 'time(sec)' ); ylabel( 'joint pos(rad/s)' ); grid on; title('2nd joint velocity');



