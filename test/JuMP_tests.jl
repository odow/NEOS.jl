function run_JuMP_tests(solver, email)
    baseTests(solver, email)
    testSOS(solver, email)
    SolveDiet(solver, email)
end

function testSOS(neos_solver, email)
    # Use SOS of type II to model piecewise linear approximation
    # to model
    #   min y
    #    s/t  y =  (x-1)^2
    #         y >= 0.1x
    #         x ∈ [0, 2]


    m = Model(solver = NEOSSolver(solver=neos_solver, email=email))

    @defVar(m, 0 <= x <= 2)
    @defVar(m, y >= 0)
    @defVar(m, 0 <= λ[1:5] <= 1)

    xx = [0, 0.5, 1, 1.5, 2]
    yy = (xx - 1).^2

    @setObjective(m, :Min, y)

    addSOS2(m, [i * λ[i] for i=1:length(λ)])
    @addConstraint(m, x == dot(λ, xx))
    @addConstraint(m, y == dot(λ, yy))
    @addConstraint(m, sum(λ) == 1)

    @addConstraint(m, y >= 0.1 * x)

    status = solve(m)
    facts() do
        @fact status => :Optimal
        @fact getValue(x) => roughly(0.83333, 1e-5)
        @fact getValue(y) => roughly(0.08333, 1e-5)
    end
end

# This test taken from http://github.com/JuliaOpt/JuMP.jl/examples/diet.jl
#  Copyright 2015, Iain Dunning, Joey Huchette, Miles Lubin, and contributors
function SolveDiet(neos_solver, email)

    # Nutrition guidelines
    numCategories = 4
    categories = ["calories", "protein", "fat", "sodium"]
    minNutrition = [1800, 91, 0, 0]
    maxNutrition = [2200, Inf, 65, 1779]

    # Foods
    numFoods = 9
    foods = ["hamburger", "chicken", "hot dog", "fries",
                     "macaroni", "pizza", "salad", "milk", "ice cream"]
    cost = [2.49, 2.89, 1.50, 1.89, 2.09, 1.99, 2.49, 0.89, 1.59]
    nutritionValues = [410 24 26 730;
                       420 32 10 1190;
                       560 20 32 1800;
                       380  4 19 270;
                       320 12 10 930;
                       320 15 12 820;
                       320 31 12 1230;
                       100  8 2.5 125;
                       330  8 10 180]

    # Build model
    m = Model(solver = NEOSSolver(solver=neos_solver, email=email))

    # Variables for nutrition info
    @defVar(m, minNutrition[i] <= nutrition[i=1:numCategories] <= maxNutrition[i])
    # Variables for which foods to buy
    @defVar(m, buy[i=1:numFoods] >= 0)

    # Objective - minimize cost
    @setObjective(m, Min, dot(cost, buy))

    # Nutrition constraints
    for j = 1:numCategories
        @addConstraint(m, sum{nutritionValues[i,j]*buy[i], i=1:numFoods} == nutrition[j])
    end

    # Solve
    facts() do
        @fact solve(m) => :Optimal
        @fact getValue(buy)[:] => roughly([0.60451, 0., 0., 0., 0., 0., 0., 6.97014, 2.59132], 1e-5)
    end
end

function baseTests(solver, email)
    m = Model(solver=NEOSSolver(solver=solver, email=TESTING_EMAIL))
    @defVar(m, 0 <= x <= 1)
    @defVar(m, 0 <= y <= 1)
    @defVar(m, z, Bin)
    @setObjective(m, :Min, x + y - 2z)
    @addConstraint(m, x + y >= 5.5)
    @addConstraint(m, x >= z)

    status = solve(m)
    facts() do
        @fact status => :Infeasible
    end

    m = Model(solver=NEOSSolver(solver=solver, email=TESTING_EMAIL))
    @defVar(m, 0 <= x <= 1)
    @defVar(m, y >= 0)
    @defVar(m, z, Bin)
    @setObjective(m, :Min, x - y - 2z)
    @addConstraint(m, x + y >= 5.5)
    @addConstraint(m, x >= z)

    status = solve(m)
    facts() do
        @fact status => :Unbounded
    end

    neos_solver = NEOSSolver(solver=solver, email=TESTING_EMAIL)
    time_limits = Dict{Symbol, String}([:SYMPHONY => "time_limit", :CPLEX => "set timelimit", :XpressMP => "MAXTIME=", :scip => "limits/time ="])
    addParameter!(neos_solver, time_limits[solver] * " 60")

    m = Model(solver=neos_solver)

    @defVar(m, 0 <= x <= 0.5)
    @defVar(m, 0 <= y <= 2)
    @defVar(m, z, Bin)
    @setObjective(m, :Max, x - y + z)
    @addConstraint(m, x + 0.5y + 0.5y >= 2)
    @addConstraint(m, x >= z)

    status = solve(m)
    facts() do
        @fact status => :Optimal
        @fact getValue(x) => roughly(0.5, 1e-5)
        @fact getValue(y) => roughly(1.5, 1e-5)
        @fact getValue(z) => roughly(0.0, 1e-5)
        @fact getObjectiveValue(m) => roughly(-1.0, 1e-5)
    end
end