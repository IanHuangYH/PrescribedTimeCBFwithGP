function [T_learn, Q_learn, U_record, T_record] = runSimulation(time, x_cur)
    % Initialize a container for control inputs
    U_record = [];
    T_record = [];

    % Call ode45 with the nested systemDynamics function
    [T_learn, Q_learn] = ode45(@systemDynamics, [time(1), time(end)], x_cur);

    % Nested function for system dynamics
    function x_dot = systemDynamics(t,x)
        global gSP error_l dt_s PreCBFGP t0_s UncertaintyFlag_s
    
        [M, C, G] = TwoLinkRobotSimplified(gSP, x(1:2), x(3:4));
    
        [u_norm, error] = PDController(GetCurDesire(t,x(1:2)), x(1:2), x(3:4), error_l, dt_s, gSP);
        % update error
        error_l = error;
    
        % Prescribed time CBF
        [PreCBFGP, u_safe ] = ...
            PreCBFGP.ComputeSafeU(u_norm,x(1:2),x(3:4),t0_s,t,UncertaintyFlag_s, M, C, G);
    
        % Compute the acceleration
        acceleration = M \ (-C - G + u_safe); % M^(-1)*(-C-G+u)
    
        % Construct the derivative of the state vector
        x_dot = [x(3:4); acceleration];
        U_record = [U_record,u_safe];
        T_record = [T_record,t];
    end
end