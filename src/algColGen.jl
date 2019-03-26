function update_pricing_prob(alg::AlgToEvalNodeByLagrangianDuality,
                             sp_form::Formulation)

    @timeit to(alg) "update_pricing_prob"
    begin
        new_obj = Dict{VarId, Float64}()
        
        alg.pricing_const_obj[pricing_prob] = 0

        active = true
        static = true

        master_form = sp_form.parent_formulation
 
        var_uids = getvar_uids(sp_form, PricingSpVar)

        new_obj = get_red_costs(master_form, var_uids)

        @logmsg LogLevel(-3) string("new objective func = ", new_obj)

        set_optimizer_obj(sp_form, new_obj)

    end # @timeit to(alg) "update_pricing_prob"
    return false
end
