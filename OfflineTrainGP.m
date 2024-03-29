function GPModelClass = OfflineTrainGP(dof, MaxDataNum)
    % q_lim = [-3, 3;
    %          -3, 3 ];
    q_lim = [-4, 4;
            -4, 4 ];%org
    % q_lim = [-1, 4;
    %         -1, 2.5 ];

    [x_train,y_train] = GenerateTrainDataSet(q_lim,dof,MaxDataNum);
    
    
    Xdim = size(x_train,1);
    Ydim = size(y_train,1);
    
    % Hyperparam
    SigmaF = 1;
    SigmaL = 0.4 * ones(Xdim,1);
    % SigmaL =  [1;1;100;100]; % for q_dot
    SigmaN = 0.01;
    
    % generate GP model
    GPModelClass = LocalGP_MultiOutput(Xdim,Ydim,MaxDataNum,SigmaN,SigmaF,SigmaL);
    % train
    GPModelClass.add_Alldata(x_train, y_train);
    GPModelClass.xMin = q_lim(:,1);
    GPModelClass.xMax = q_lim(:,2);
end