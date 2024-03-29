function [mod_CBF_coe, eta] = ConsiderGPerrorboundCBF(org_CBF_coe, GP_model, x_data, dhndxn)
% dhdxn = 1*2
    [mu,var,eta,beta,gamma,eta_min] = GP_model.predict(x_data);
    abs_eta_mat = [eta;eta];
    phi = -abs(dhndxn) * (abs_eta_mat) + dhndxn * mu;
    mod_CBF_coe = org_CBF_coe + phi;
end