dof = 2;
MaxDataNum = 400;
q_lim = [-1, 1;
         -1, 1 ];

[x_train,y_train] = GenerateTrainDataSet(q_lim,dof,MaxDataNum);


Xdim = size(x_train,1);
Ydim = size(y_train,1);

% Hyperparam
SigmaF = 1;
SigmaL = 0.2 * ones(Xdim,1);
SigmaN = 0.01;

% generate GP model
LocalGP = LocalGP_MultiOutput(Xdim,Ydim,MaxDataNum,SigmaN,SigmaF,SigmaL);
% train
LocalGP.add_Alldata(x_train, y_train);
LocalGP.xMin = q_lim(:,1);
LocalGP.xMax = q_lim(:,2);

% validation
time = 5;



[mu,var,eta,beta,gamma,eta_min] = LocalGP.predict(x_now);