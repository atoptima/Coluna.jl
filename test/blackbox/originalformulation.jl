function test_membership(inner_model, orig_form, constraint)
    constr_obj = JuMP.constraint_object(constraint)
    c_constr_id = CL.moi2cid(inner_model, constraint.index).value
    members_of_constr = CL.get_var_members_of_constr(orig_form, c_constr_id)
    for term in JuMP.jump_function(constr_obj).terms
        m_var_id = term[1].index
        coeff = term[2]
        c_var_id = CL.moi2cid(inner_model, m_var_id).value
        @test members_of_constr[c_var_id] == coeff
        members_of_var = CL.get_constr_members_of_var(orig_form, c_var_id)
        @test members_of_var[c_constr_id] == coeff
    end
    return
end


function test_memberships_sgap(model, inner_model, orig_form)
    knp_constrs = model[:knp]
    cov_constrs = model[:cov]
    for knp_constr in knp_constrs
        test_membership(inner_model, orig_form, knp_constr)
    end
    for cov_constr in cov_constrs
        test_membership(inner_model, orig_form, cov_constr)
    end
    return
end

function blackbox_original_formulation_sgap()
    model, x = sgap_play()
    JuMP.optimize!(model)
    inner_model = JuMP.backend(model).optimizer.model.optimizer.inner
    orig_form = CL.get_original_formulation(inner_model)
    
    # Number of variables & constraints in the formulation
    @test length(orig_form.vars) == 14
    @test length(orig_form.constrs) == 9

    test_memberships_sgap(model, inner_model, orig_form)
end