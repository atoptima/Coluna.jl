function model_scsp(d::DataCsp)
  params = Coluna.Params(use_restricted_master_heur = true)

  csp = Model(with_optimizer(Coluna.ColunaModelOptimizer, params),
              bridge_constraints = false)

  xub = [ min(d.orders[o].demand, floor(d.stocksheetswidth/d.orders[o].width))
          for o in 1:d.nborders ]

  @variable(csp, 0 <= x[o in 1:d.nborders] <= xub[o])

  @variable(csp, y, Bin)

  @constraint(csp, cov[o in 1:d.nborders], x[o] >= d.orders[o].demand)

  @constraint(csp, knp,
      sum(x[o] * d.orders[o].width for o in 1:d.nborders)
      - y * d.stocksheetswidth <= 0)

  @objective(csp, Min, y)

  # setting constraint annotations for the decomposition
  for o in 1:d.nborders
      set(csp, Coluna.ConstraintDantzigWolfeAnnotation(), cov[o], 0)
  end

  set(csp, Coluna.ConstraintDantzigWolfeAnnotation(), knp, 1)

  # setting variable annotations for the decomposition
  for o in 1:d.nborders
      set(csp, Coluna.VariableDantzigWolfeAnnotation(), x[o], 1)
  end

  set(csp, Coluna.VariableDantzigWolfeAnnotation(), y, 1)

  # setting pricing cardinality bounds
  card_bounds_dict = Dict(1 => (0,10))
  set(csp, Coluna.DantzigWolfePricingCardinalityBounds(), card_bounds_dict)

  return (csp, x,  y)
end
