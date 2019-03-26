
function blackbox_original_formulation()
    model, x = sgap_play()
    JuMP.optimize!(model)
    @show JuMP.backend(model).optimizer.model.optimizer.inner
end