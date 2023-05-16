# # Translational Oscillations by a Rotational Actuator (TORA)
#
#md # [![](https://img.shields.io/badge/show-nbviewer-579ACA.svg)](@__NBVIEWER_ROOT_URL__/models/Sherlock-Benchmark-9-TORA.ipynb)

module TORA  #jl

using ClosedLoopReachability, MAT, Plots
import DifferentialEquations
using ClosedLoopReachability: UniformAdditivePostprocessing, NoSplitter,
                              LinearMapPostprocessing

# The following option determines whether the verification settings should be
# used or not. The verification settings are chosen to show that the safety
# property is satisfied. Concretely we split the initial states into small
# chunks and run many analyses.
const verification = true;

# This model consists of a cart attached to a wall with a spring. The cart is
# free to move on a friction-less surface. The car has a weight attached to an
# arm, which is free to rotate about an axis. This serves as the control input
# to stabilize the cart at $x = 0$.
#
# ## Model
#
# The model is four dimensional, given by the following equations:
#
# ```math
# \left\{ \begin{array}{lcl}
#       \dot{x}_1 &=& x_2 \\
#       \dot{x}_2 &=& -x_1 + 0.1 \sin(x_3) \\
#       \dot{x}_3 &=& x_4  \\
#       \dot{x}_4 &=& u
# \end{array} \right.
# ```
#
# A neural network controller was trained for this system. The trained network
# has 3 hidden layers, with 100 neurons in each layer (i.e., a total of 300
# neurons). Note that the output of the neural network $f(x)$ needs to be
# normalized in order to obtain $u$, namely $u = f(x) - 10$. The sampling time
# for this controller is 1s.

@taylorize function TORA!(dx, x, p, t)
    x₁, x₂, x₃, x₄, u = x

    aux = 0.1 * sin(x₃)
    dx[1] = x₂
    dx[2] = -x₁ + aux
    dx[3] = x₄
    dx[4] = u
    dx[5] = zero(u)
    return dx
end;

# We consider three types of controllers: a ReLU controller, a sigmoid
# controller, and a mixed relu/tanh controller.

path = @modelpath("Sherlock-Benchmark-9-TORA", "controllerTora.mat")
controller_relu = read_nnet_mat(path, act_key="act_fcns")

path = @modelpath("Sherlock-Benchmark-9-TORA", "nn_tora_sigmoid.mat")
controller_sigmoid = read_nnet_mat(path, act_key="act_fcns")

path = @modelpath("Sherlock-Benchmark-9-TORA", "nn_tora_relu_tanh.mat")
controller_relutanh = read_nnet_mat(path, act_key="act_fcns");

# ## Specification

# The verification problem is safety. For an initial set of $x_1 ∈ [0.6, 0.7]$,
# $x_2 ∈ [−0.7, −0.6]$, $x_3 ∈ [−0.4, −0.3]$, and $x_4 ∈ [0.5, 0.6]$, the
# system has to stay within the box $x ∈ [−2, 2]^4$ for a time window of 20s.
# For the non-ReLU controllers, different settings apply.

X₀_ReLU = Hyperrectangle(low=[0.6, -0.7, -0.4, 0.5], high=[0.7, -0.6, -0.3, 0.6])
X₀_others = Hyperrectangle(low=[-0.77, -0.45, 0.51, -0.3], high=[-0.75, -0.43, 0.54, -0.28])
U = ZeroSet(1)

vars_idx = Dict(:states=>1:4, :controls=>5)
ivp(X₀) = @ivp(x' = TORA!(x), dim: 5, x(0) ∈ X₀ × U)

period_ReLU = 1.0  # control period for ReLU network
period_others = 0.5  # control period for other networks

# control postprocessing
control_postprocessing_ReLU = UniformAdditivePostprocessing(-10.0)
control_postprocessing_others = LinearMapPostprocessing(11.0)

problem(controller, period, X₀, control_postprocessing) =
    ControlledPlant(ivp(X₀), controller, vars_idx, period;
                    postprocessing=control_postprocessing)

## Safety specification
T_ReLU = 20.0  # time horizon for ReLU network
T_others = 5.0  # time horizon for other networks
T_warmup_ReLU = 2 * period_ReLU  # shorter time horizon for dry run (for ReLU network)
T_warmup_others = 2 * period_others  # shorter time horizon for dry run (for other networks)

safe_states = cartesian_product(BallInf(zeros(4), 2.0), Universe(1))
goal_states_x1x2 = Hyperrectangle(low=[-0.1, -0.9], high=[0.2, -0.6])
goal_states = cartesian_product(goal_states_x1x2, Universe(3))

predicate_safety = X -> X ⊆ safe_states
predicate_reachability =
    sol -> project(sol[end][end], [1, 2]) ⊆ goal_states_x1x2;

# ## Results

alg = TMJets(abstol=1e-10, orderT=8, orderQ=3)
alg_nn = DeepZ()

function benchmark(prob; T, splitter, predicate, silent::Bool=false)
    ## We solve the controlled system:
    silent || println("flowpipe construction")
    res_sol = @timed sol = solve(prob, T=T, alg_nn=alg_nn, alg=alg,
                                 splitter=splitter)
    sol = res_sol.value
    silent || print_timed(res_sol)

    ## Next we check the property for an overapproximated flowpipe:
    silent || println("property checking")
    solz = overapproximate(sol, Zonotope)
    res_pred = @timed predicate(solz)
    silent || print_timed(res_pred)
    if res_pred.value
        silent || println("The property is satisfied.")
    else
        silent || println("The property may be violated.")
    end
    return solz
end

function plot_helper!(fig, sol, sim, vars, T, X₀, property; zoom=nothing)
    if property == "safety"
        states = safe_states
    elseif property == "reachability"
        states = goal_states
    end
    if vars[1] == 0
        states_projected = project(states, [vars[2]])
        time = Interval(0, T)
        states_projected = cartesian_product(time, states_projected)
    else
        states_projected = project(states, vars)
    end
    if property == "safety"
        plot!(fig, states_projected, color=:lightgreen, lab="safe states")
    elseif property == "reachability"
        plot!(fig, states_projected, color=:cyan, lab="target states")
    end
    plot!(fig, sol, vars=vars, color=:yellow, lab="")
    plot_simulation!(fig, sim; vars=vars, color=:black, lab="")
    if !isnothing(zoom)
        zoom()
    end
end

TARGET_FOLDER = isdefined(Main, :TARGET_FOLDER) ? Main.TARGET_FOLDER : @__DIR__

for case in 1:3
    if case == 1
        println("Running analysis with ReLU controller")
        prob = problem(controller_relu, period_ReLU, X₀_ReLU,
                       control_postprocessing_ReLU)
        predicate = predicate_safety
        scenario = "relu"
        T_reach = verification ? T_ReLU : T_warmup_ReLU  # shorter time horizon if not verifying
        T_warmup = T_warmup_ReLU
        X₀ = X₀_ReLU
        splitter = verification ? BoxSplitter([4, 4, 3, 5]) : NoSplitter()
        trajectories = 10
        plot_x3_x4 = true
        property = "safety"
        zoom = nothing
    elseif case == 2
        println("Running analysis with sigmoid controller")
        prob = problem(controller_sigmoid, period_others, X₀_others,
                       control_postprocessing_others)
        predicate = predicate_reachability
        scenario = "sigmoid"
        T_reach = T_others
        T_warmup = T_warmup_others
        X₀ = X₀_others
        splitter = NoSplitter()
        trajectories = 1
        plot_x3_x4 = false
        property = "reachability"
        zoom = () -> lens!(fig, [0.1, 0.25], [-0.9, -0.8], inset = (1, bbox(0.4, 0.4, 0.3, 0.3)), lc=:black)
    else
        println("Running analysis with ReLU/tanh controller")
        prob = problem(controller_relutanh, period_others, X₀_others,
                       control_postprocessing_others)
        predicate = predicate_reachability
        scenario = "relutanh"
        T_reach = T_others
        T_warmup = T_warmup_others
        X₀ = X₀_others
        splitter = NoSplitter()
        trajectories = 1
        plot_x3_x4 = false
        property = "reachability"
        zoom = () -> lens!(fig, [0.0, 0.25], [-0.85, -0.7], inset = (1, bbox(0.4, 0.4, 0.3, 0.3)), lc=:black)
    end

    benchmark(prob; T=T_warmup, splitter=NoSplitter(), predicate=predicate, silent=true)  # warm-up
    res = @timed benchmark(prob; T=T_reach, splitter=splitter, predicate=predicate)  # benchmark
    sol = res.value
    println("total analysis time")
    print_timed(res);
    io = isdefined(Main, :io) ? Main.io : stdout
    print(io, "TORA,$scenario,verified,$(res.time)\n")

    # We also compute some simulations:

    println("simulation")
    res = @timed simulate(prob, T=T_reach; trajectories=trajectories,
                          include_vertices=true)
    sim = res.value
    print_timed(res);

    # Finally we plot the results

    vars = (1, 2)
    fig = plot(xlab="x₁", ylab="x₂")
    plot_helper!(fig, sol, sim, vars, T_reach, X₀, property; zoom=zoom)
    savefig(fig, joinpath(TARGET_FOLDER, "TORA-$scenario-x1-x2.png"))

    if plot_x3_x4
        vars=(3, 4)
        fig = plot(xlab="x₃", ylab="x₄")
        plot_helper!(fig, sol, sim, vars, T_reach, X₀, property)
        savefig(fig, joinpath(TARGET_FOLDER, "TORA-$scenario-x3-x4.png"))
    end
end

end  #jl
nothing  #jl
