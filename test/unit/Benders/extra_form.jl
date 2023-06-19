## optimal solution is found with 1st level variables y equals to:
## y1 = 1.0, y2 = 0.0, y3 = 1.0
## with 2nd level variables:
## x12 = x14 = x32 = x33 = 1.0
## mlp = 385.0
## a sub-optimal solution can be found with 1st level variables:
## y1 = 1.0, y2 = 1.0, y3 = 0.0 (fix y3 to zero)
## with 2nd level variables:
## x12 = x22 = x23 = 1.0
## mlp = 517.0
## if y1 is fixed to zero, the problem is infeasible


## [Relaxation]
## optimal solution is found with 1st level variables y equals to:
## y1 = 0.5, y2 = 0.0, y3 = 0.33333
## with 2nd level variables:
## x11 = 0.5, x12 = 0.5, x13 = 0.49999, x14 = 0.5, x31 = 1/3, x32 = 1/3, x33 = 0.16666, x34 = 1/3
## mlp = 293.5
## a sub-optimal solution can be found with 1st level variables:
## y1 = 0.5, y2 = 0.5, y3 = 0.0 (fix y3 to zero)
## with 2nd level variables:
## x11 = 0.5, x12 = 0.5, x13 = 0.5, x21 = 0.5, x22 = 0.5, x23 = 0.5
## mlp = 386.00
## if y1 is fixed to zero, the problem is infeasible
function benders_form_location_routing()
    form = """
    master
        min
        150y1 + 210y2 + 130y3 + z
        s.t.
        y1 + y2 + y3 >= 0

    benders_sp
        min
        0y1 + 0y2 + 0y3 + 100x11 + 50x12 + 75x13 + 15x14 + 80x21 + 40x22 + 67x23 + 24x24 + 70x31 + 5x32 + 35x33 + 73x34 + z + local_art_of_open1 + local_art_of_open2 + local_art_of_open3 + local_art_of_open4 + local_art_of_open5 + local_art_of_open6 + local_art_of_open7 + local_art_of_open8 + local_art_of_open9 + local_art_of_open10 + local_art_of_open11 + local_art_of_open12 + local_art_of_cov1 + local_art_of_cov2 + local_art_of_cov3 + local_art_of_cov4 + local_art_of_cov5 + local_art_of_limit_nb_routes1 + local_art_of_limit_nb_routes2 + local_art_of_limit_nb_routes3
        s.t.
        y1 - x11 + local_art_of_open1 >= 0 {BendTechConstr}
        y1 - x12 + local_art_of_open2 >= 0 {BendTechConstr}
        y1 - x13 + local_art_of_open3 >= 0 {BendTechConstr}
        y1 - x14 + local_art_of_open4 >= 0 {BendTechConstr}
        y2 - x21 + local_art_of_open5 >= 0 {BendTechConstr}
        y2 - x22 + local_art_of_open6 >= 0 {BendTechConstr}
        y2 - x23 + local_art_of_open7 >= 0 {BendTechConstr}
        y2 - x24 + local_art_of_open8 >= 0 {BendTechConstr}
        y3 - x31 + local_art_of_open9 >= 0 {BendTechConstr}
        y3 - x32 + local_art_of_open10 >= 0 {BendTechConstr}
        y3 - x33 + local_art_of_open11 >= 0 {BendTechConstr}
        y3 - x34 + local_art_of_open12 >= 0 {BendTechConstr}
        x11 + x12 + local_art_of_cov1 >= 1
        x12 + x13 + x21 + x23 + x31 + x34 + local_art_of_cov2 >= 1
        x13 + x22 + x33 + x34 + local_art_of_cov3 >= 1
        x13 + x14 + x21 + x22 + x24 + local_art_of_cov4 >= 1
        x21 + x23 + x31 + x32 + x34 + local_art_of_cov5 >= 1
        x11 + x12 + x13 + x14 + local_art_of_limit_nb_routes1 <= 3
        x21 + x22 + x23 + x24 + local_art_of_limit_nb_routes2 <= 3
        x31 + x32 + x33 + x34 + local_art_of_limit_nb_routes3 <= 3
        x11 + x12 + x13 + x14 + x21 + x22 + x23 + x24 + x31 + x32 + x33 + x34 + local_art_of_open1 + local_art_of_open2 + local_art_of_open3 + local_art_of_open4 + local_art_of_open5 + local_art_of_open6 + local_art_of_open7 + local_art_of_open8 + local_art_of_open9 + local_art_of_open10 + local_art_of_open11 + local_art_of_open12 + local_art_of_cov1 + local_art_of_cov2 + local_art_of_cov3 + local_art_of_cov4 + local_art_of_cov5 + local_art_of_limit_nb_routes1 + local_art_of_limit_nb_routes2 + local_art_of_limit_nb_routes3 

    integer
        first_stage
            y1, y2, y3

    continuous
        second_stage_cost
            z
        second_stage
            x11, x12, x13, x14, x21, x22, x23, x24, x31, x32, x33, x34

        second_stage_artificial
            local_art_of_open1, local_art_of_open2, local_art_of_open3, local_art_of_open4, local_art_of_open5, local_art_of_open6, local_art_of_open7, local_art_of_open8, local_art_of_open9, local_art_of_open10, local_art_of_open11, local_art_of_open12, local_art_of_cov1, local_art_of_cov2, local_art_of_cov3, local_art_of_cov4, local_art_of_cov5, local_art_of_limit_nb_routes1, local_art_of_limit_nb_routes2, local_art_of_limit_nb_routes3

    bounds
        -Inf <= z <= Inf
        0 <= x11 <= 1
        0 <= x12 <= 1
        0 <= x13 <= 1
        0 <= x14 <= 1
        0 <= x21 <= 1
        0 <= x22 <= 1
        0 <= x23 <= 1
        0 <= x24 <= 1
        0 <= x31 <= 1
        0 <= x32 <= 1
        0 <= x33 <= 1
        0 <= x34 <= 1
        0 <= y1 <= 1
        0 <= y2 <= 1
        0 <= y3 <= 1
        0 <= local_art_of_open1 <= Inf
        0 <= local_art_of_open2 <= Inf
        0 <= local_art_of_open3 <= Inf
        0 <= local_art_of_open4 <= Inf
        0 <= local_art_of_open5 <= Inf 
        0 <= local_art_of_open6 <= Inf
        0 <= local_art_of_open7 <= Inf 
        0 <= local_art_of_open8 <= Inf 
        0 <= local_art_of_open9 <= Inf 
        0 <= local_art_of_open10 <= Inf
        0 <= local_art_of_open11 <= Inf
        0 <= local_art_of_open12 <= Inf
        0 <= local_art_of_cov1 <= Inf
        0 <= local_art_of_cov2 <= Inf
        0 <= local_art_of_cov3 <= Inf
        0 <= local_art_of_cov4 <= Inf
        0 <= local_art_of_cov5 <= Inf
        0 <= local_art_of_limit_nb_routes1 <= Inf
        0 <= local_art_of_limit_nb_routes2 <= Inf
        0 <= local_art_of_limit_nb_routes3 <= Inf
    """
    env, _, _, _, reform = reformfromstring(form)
    return env, reform
end

function benders_form_location_routing_fixed_opt_continuous()
    form = """
    master
        min
        150y1 + 210y2 + 130y3 + z
        s.t.
        y1 + y2 + y3 >= 0

    benders_sp
        min
        0y1 + 0y2 + 0y3 + 100x11 + 50x12 + 75x13 + 15x14 + 80x21 + 40x22 + 67x23 + 24x24 + 70x31 + 5x32 + 35x33 + 73x34 + z + local_art_of_open1 + local_art_of_open2 + local_art_of_open3 + local_art_of_open4 + local_art_of_open5 + local_art_of_open6 + local_art_of_open7 + local_art_of_open8 + local_art_of_open9 + local_art_of_open10 + local_art_of_open11 + local_art_of_open12 + local_art_of_cov1 + local_art_of_cov2 + local_art_of_cov3 + local_art_of_cov4 + local_art_of_cov5 + local_art_of_limit_nb_routes1 + local_art_of_limit_nb_routes2 + local_art_of_limit_nb_routes3
        s.t.
        y1 - x11 + local_art_of_open1 >= 0 {BendTechConstr}
        y1 - x12 + local_art_of_open2 >= 0 {BendTechConstr}
        y1 - x13 + local_art_of_open3 >= 0 {BendTechConstr}
        y1 - x14 + local_art_of_open4 >= 0 {BendTechConstr}
        y2 - x21 + local_art_of_open5 >= 0 {BendTechConstr}
        y2 - x22 + local_art_of_open6 >= 0 {BendTechConstr}
        y2 - x23 + local_art_of_open7 >= 0 {BendTechConstr}
        y2 - x24 + local_art_of_open8 >= 0 {BendTechConstr}
        y3 - x31 + local_art_of_open9 >= 0 {BendTechConstr}
        y3 - x32 + local_art_of_open10 >= 0 {BendTechConstr}
        y3 - x33 + local_art_of_open11 >= 0 {BendTechConstr}
        y3 - x34 + local_art_of_open12 >= 0 {BendTechConstr}
        x11 + x12 + local_art_of_cov1 >= 1
        x12 + x13 + x21 + x23 + x31 + x34 + local_art_of_cov2 >= 1
        x13 + x22 + x33 + x34 + local_art_of_cov3 >= 1
        x13 + x14 + x21 + x22 + x24 + local_art_of_cov4 >= 1
        x21 + x23 + x31 + x32 + x34 + local_art_of_cov5 >= 1
        x11 + x12 + x13 + x14 + local_art_of_limit_nb_routes1 <= 3
        x21 + x22 + x23 + x24 + local_art_of_limit_nb_routes2 <= 3
        x31 + x32 + x33 + x34 + local_art_of_limit_nb_routes3 <= 3
        x11 + x12 + x13 + x14 + x21 + x22 + x23 + x24 + x31 + x32 + x33 + x34 + local_art_of_open1 + local_art_of_open2 + local_art_of_open3 + local_art_of_open4 + local_art_of_open5 + local_art_of_open6 + local_art_of_open7 + local_art_of_open8 + local_art_of_open9 + local_art_of_open10 + local_art_of_open11 + local_art_of_open12 + local_art_of_cov1 + local_art_of_cov2 + local_art_of_cov3 + local_art_of_cov4 + local_art_of_cov5 + local_art_of_limit_nb_routes1 + local_art_of_limit_nb_routes2 + local_art_of_limit_nb_routes3 

    continuous
        first_stage
            y1, y2, y3

    continuous
        second_stage_cost
            z
        second_stage
            x11, x12, x13, x14, x21, x22, x23, x24, x31, x32, x33, x34

        second_stage_artificial
            local_art_of_open1, local_art_of_open2, local_art_of_open3, local_art_of_open4, local_art_of_open5, local_art_of_open6, local_art_of_open7, local_art_of_open8, local_art_of_open9, local_art_of_open10, local_art_of_open11, local_art_of_open12, local_art_of_cov1, local_art_of_cov2, local_art_of_cov3, local_art_of_cov4, local_art_of_cov5, local_art_of_limit_nb_routes1, local_art_of_limit_nb_routes2, local_art_of_limit_nb_routes3

    bounds
        175.16666666666666 <= z <= 175.16666666666666
        0.5 <= x11 <= 0.5
        0.5 <= x12 <= 0.5
        0.49999 <= x13 <= 0.49999
        0.5 <= x14 <= 0.5
        0 <= x21 <= 0
        0 <= x22 <= 0
        0 <= x23 <= 0
        0 <= x24 <= 0
        0.33333 <= x31 <= 0.33333
        0.33333 <= x32 <= 0.33333
        0.16666 <= x33 <= 0.16666
        0.33333 <= x34 <= 0.33333
        0.5 <= y1 <= 0.5
        0.0 <= y2 <= 0.0
        0.3333 <= y3 <= 0.3333
        0 <= local_art_of_open1 <= Inf
        0 <= local_art_of_open2 <= Inf
        0 <= local_art_of_open3 <= Inf
        0 <= local_art_of_open4 <= Inf
        0 <= local_art_of_open5 <= Inf 
        0 <= local_art_of_open6 <= Inf
        0 <= local_art_of_open7 <= Inf 
        0 <= local_art_of_open8 <= Inf 
        0 <= local_art_of_open9 <= Inf 
        0 <= local_art_of_open10 <= Inf
        0 <= local_art_of_open11 <= Inf
        0 <= local_art_of_open12 <= Inf
        0 <= local_art_of_cov1 <= Inf
        0 <= local_art_of_cov2 <= Inf
        0 <= local_art_of_cov3 <= Inf
        0 <= local_art_of_cov4 <= Inf
        0 <= local_art_of_cov5 <= Inf
        0 <= local_art_of_limit_nb_routes1 <= Inf
        0 <= local_art_of_limit_nb_routes2 <= Inf
        0 <= local_art_of_limit_nb_routes3 <= Inf
    """
    env, _, _, _, reform = reformfromstring(form)
    return env, reform
end



function benders_form_location_routing_infeasible()
    form = """
    master
        min
        150y1 + 210y2 + 130y3 + z
        s.t.
        y1 + y2 + y3 >= 0

    benders_sp
        min
        0y1 + 0y2 + 0y3 + 100x11 + 50x12 + 75x13 + 15x14 + 80x21 + 40x22 + 67x23 + 24x24 + 70x31 + 5x32 + 35x33 + 73x34 + z + local_art_of_open1 + local_art_of_open2 + local_art_of_open3 + local_art_of_open4 + local_art_of_open5 + local_art_of_open6 + local_art_of_open7 + local_art_of_open8 + local_art_of_open9 + local_art_of_open10 + local_art_of_open11 + local_art_of_open12 + local_art_of_cov1 + local_art_of_cov2 + local_art_of_cov3 + local_art_of_cov4 + local_art_of_cov5 + local_art_of_limit_nb_routes1 + local_art_of_limit_nb_routes2 + local_art_of_limit_nb_routes3
        s.t.
        y1 - x11 + local_art_of_open1 >= 0 {BendTechConstr}
        y1 - x12 + local_art_of_open2 >= 0 {BendTechConstr}
        y1 - x13 + local_art_of_open3 >= 0 {BendTechConstr}
        y1 - x14 + local_art_of_open4 >= 0 {BendTechConstr}
        y2 - x21 + local_art_of_open5 >= 0 {BendTechConstr}
        y2 - x22 + local_art_of_open6 >= 0 {BendTechConstr}
        y2 - x23 + local_art_of_open7 >= 0 {BendTechConstr}
        y2 - x24 + local_art_of_open8 >= 0 {BendTechConstr}
        y3 - x31 + local_art_of_open9 >= 0 {BendTechConstr}
        y3 - x32 + local_art_of_open10 >= 0 {BendTechConstr}
        y3 - x33 + local_art_of_open11 >= 0 {BendTechConstr}
        y3 - x34 + local_art_of_open12 >= 0 {BendTechConstr}
        x11 + x12 + local_art_of_cov1 >= 1
        x12 + x13 + x21 + x23 + x31 + x34 + local_art_of_cov2 >= 1
        x13 + x22 + x33 + x34 + local_art_of_cov3 >= 1
        x13 + x14 + x21 + x22 + x24 + local_art_of_cov4 >= 1
        x21 + x23 + x31 + x32 + x34 + local_art_of_cov5 >= 1
        x11 + x12 + x13 + x14 + local_art_of_limit_nb_routes1 <= 3
        x21 + x22 + x23 + x24 + local_art_of_limit_nb_routes2 <= 3
        x31 + x32 + x33 + x34 + local_art_of_limit_nb_routes3 <= 3
        x11 + x12 + x13 + x14 + x21 + x22 + x23 + x24 + x31 + x32 + x33 + x34 + local_art_of_open1 + local_art_of_open2 + local_art_of_open3 + local_art_of_open4 + local_art_of_open5 + local_art_of_open6 + local_art_of_open7 + local_art_of_open8 + local_art_of_open9 + local_art_of_open10 + local_art_of_open11 + local_art_of_open12 + local_art_of_cov1 + local_art_of_cov2 + local_art_of_cov3 + local_art_of_cov4 + local_art_of_cov5 + local_art_of_limit_nb_routes1 + local_art_of_limit_nb_routes2 + local_art_of_limit_nb_routes3 

    integer
        first_stage
            y1, y2, y3

    continuous
        second_stage_cost
            z
        second_stage
            x11, x12, x13, x14, x21, x22, x23, x24, x31, x32, x33, x34

        second_stage_artificial
            local_art_of_open1, local_art_of_open2, local_art_of_open3, local_art_of_open4, local_art_of_open5, local_art_of_open6, local_art_of_open7, local_art_of_open8, local_art_of_open9, local_art_of_open10, local_art_of_open11, local_art_of_open12, local_art_of_cov1, local_art_of_cov2, local_art_of_cov3, local_art_of_cov4, local_art_of_cov5, local_art_of_limit_nb_routes1, local_art_of_limit_nb_routes2, local_art_of_limit_nb_routes3

    bounds
        -Inf <= z <= Inf
        0 <= x11 <= 1
        0 <= x12 <= 1
        0 <= x13 <= 1
        0 <= x14 <= 1
        0 <= x21 <= 1
        0 <= x22 <= 1
        0 <= x23 <= 1
        0 <= x24 <= 1
        0 <= x31 <= 1
        0 <= x32 <= 1
        0 <= x33 <= 1
        0 <= x34 <= 1
        0 <= y1 <= 0
        0 <= y2 <= 1
        0 <= y3 <= 1
        0 <= local_art_of_open1 <= Inf
        0 <= local_art_of_open2 <= Inf
        0 <= local_art_of_open3 <= Inf
        0 <= local_art_of_open4 <= Inf
        0 <= local_art_of_open5 <= Inf 
        0 <= local_art_of_open6 <= Inf
        0 <= local_art_of_open7 <= Inf 
        0 <= local_art_of_open8 <= Inf 
        0 <= local_art_of_open9 <= Inf 
        0 <= local_art_of_open10 <= Inf
        0 <= local_art_of_open11 <= Inf
        0 <= local_art_of_open12 <= Inf
        0 <= local_art_of_cov1 <= Inf
        0 <= local_art_of_cov2 <= Inf
        0 <= local_art_of_cov3 <= Inf
        0 <= local_art_of_cov4 <= Inf
        0 <= local_art_of_cov5 <= Inf
        0 <= local_art_of_limit_nb_routes1 <= Inf
        0 <= local_art_of_limit_nb_routes2 <= Inf
        0 <= local_art_of_limit_nb_routes3 <= Inf
    """
    env, _, _, _, reform = reformfromstring(form)
    return env, reform
end

function benders_form_location_routing_subopt()
    form = """
    master
        min
        150y1 + 210y2 + 130y3 + z
        s.t.
        y1 + y2 + y3 >= 0

    benders_sp
        min
        0y1 + 0y2 + 0y3 + 100x11 + 50x12 + 75x13 + 15x14 + 80x21 + 40x22 + 67x23 + 24x24 + 70x31 + 5x32 + 35x33 + 73x34 + z + local_art_of_open1 + local_art_of_open2 + local_art_of_open3 + local_art_of_open4 + local_art_of_open5 + local_art_of_open6 + local_art_of_open7 + local_art_of_open8 + local_art_of_open9 + local_art_of_open10 + local_art_of_open11 + local_art_of_open12 + local_art_of_cov1 + local_art_of_cov2 + local_art_of_cov3 + local_art_of_cov4 + local_art_of_cov5 + local_art_of_limit_nb_routes1 + local_art_of_limit_nb_routes2 + local_art_of_limit_nb_routes3
        s.t.
        y1 - x11 + local_art_of_open1 >= 0 {BendTechConstr}
        y1 - x12 + local_art_of_open2 >= 0 {BendTechConstr}
        y1 - x13 + local_art_of_open3 >= 0 {BendTechConstr}
        y1 - x14 + local_art_of_open4 >= 0 {BendTechConstr}
        y2 - x21 + local_art_of_open5 >= 0 {BendTechConstr}
        y2 - x22 + local_art_of_open6 >= 0 {BendTechConstr}
        y2 - x23 + local_art_of_open7 >= 0 {BendTechConstr}
        y2 - x24 + local_art_of_open8 >= 0 {BendTechConstr}
        y3 - x31 + local_art_of_open9 >= 0 {BendTechConstr}
        y3 - x32 + local_art_of_open10 >= 0 {BendTechConstr}
        y3 - x33 + local_art_of_open11 >= 0 {BendTechConstr}
        y3 - x34 + local_art_of_open12 >= 0 {BendTechConstr}
        x11 + x12 + local_art_of_cov1 >= 1
        x12 + x13 + x21 + x23 + x31 + x34 + local_art_of_cov2 >= 1
        x13 + x22 + x33 + x34 + local_art_of_cov3 >= 1
        x13 + x14 + x21 + x22 + x24 + local_art_of_cov4 >= 1
        x21 + x23 + x31 + x32 + x34 + local_art_of_cov5 >= 1
        x11 + x12 + x13 + x14 + local_art_of_limit_nb_routes1 <= 3
        x21 + x22 + x23 + x24 + local_art_of_limit_nb_routes2 <= 3
        x31 + x32 + x33 + x34 + local_art_of_limit_nb_routes3 <= 3
        x11 + x12 + x13 + x14 + x21 + x22 + x23 + x24 + x31 + x32 + x33 + x34 + local_art_of_open1 + local_art_of_open2 + local_art_of_open3 + local_art_of_open4 + local_art_of_open5 + local_art_of_open6 + local_art_of_open7 + local_art_of_open8 + local_art_of_open9 + local_art_of_open10 + local_art_of_open11 + local_art_of_open12 + local_art_of_cov1 + local_art_of_cov2 + local_art_of_cov3 + local_art_of_cov4 + local_art_of_cov5 + local_art_of_limit_nb_routes1 + local_art_of_limit_nb_routes2 + local_art_of_limit_nb_routes3 

    integer
        first_stage
            y1, y2, y3

    continuous
        second_stage_cost
            z
        second_stage
            x11, x12, x13, x14, x21, x22, x23, x24, x31, x32, x33, x34

        second_stage_artificial
            local_art_of_open1, local_art_of_open2, local_art_of_open3, local_art_of_open4, local_art_of_open5, local_art_of_open6, local_art_of_open7, local_art_of_open8, local_art_of_open9, local_art_of_open10, local_art_of_open11, local_art_of_open12, local_art_of_cov1, local_art_of_cov2, local_art_of_cov3, local_art_of_cov4, local_art_of_cov5, local_art_of_limit_nb_routes1, local_art_of_limit_nb_routes2, local_art_of_limit_nb_routes3

    bounds
        -Inf <= z <= Inf
        0 <= x11 <= 1
        0 <= x12 <= 1
        0 <= x13 <= 1
        0 <= x14 <= 1
        0 <= x21 <= 1
        0 <= x22 <= 1
        0 <= x23 <= 1
        0 <= x24 <= 1
        0 <= x31 <= 1
        0 <= x32 <= 1
        0 <= x33 <= 1
        0 <= x34 <= 1
        0 <= y1 <= 1
        0 <= y2 <= 1
        0 <= y3 <= 0
        0 <= local_art_of_open1 <= Inf
        0 <= local_art_of_open2 <= Inf
        0 <= local_art_of_open3 <= Inf
        0 <= local_art_of_open4 <= Inf
        0 <= local_art_of_open5 <= Inf 
        0 <= local_art_of_open6 <= Inf
        0 <= local_art_of_open7 <= Inf 
        0 <= local_art_of_open8 <= Inf 
        0 <= local_art_of_open9 <= Inf 
        0 <= local_art_of_open10 <= Inf
        0 <= local_art_of_open11 <= Inf
        0 <= local_art_of_open12 <= Inf
        0 <= local_art_of_cov1 <= Inf
        0 <= local_art_of_cov2 <= Inf
        0 <= local_art_of_cov3 <= Inf
        0 <= local_art_of_cov4 <= Inf
        0 <= local_art_of_cov5 <= Inf
        0 <= local_art_of_limit_nb_routes1 <= Inf
        0 <= local_art_of_limit_nb_routes2 <= Inf
        0 <= local_art_of_limit_nb_routes3 <= Inf
    """
    env, _, _, _, reform = reformfromstring(form)
    return env, reform
end






