using PyPlot
using Random


include("DataGen.jl") # This has many packages in it's preamble
include("../../Tools/Model_Reduction_Dev.jl")

#SDE parameters
sigma    = [.3]
V_prime  = x -> -x.*(x.^2 .- 1)
sig_init = [1.5]
# Numerical estimate parameters
scheme   = "FE"
steps    = 10^7  # Number of time steps (not including those discarded)
h        = .1
discard  = steps # Number of time steps discarded
gap      = 1   # 1 + the number of time steps between observations

# Get full model run
Random.seed!(2014)
X = @time DataGen_DWOL(;
    #SDE parameters
    sigma, V_prime, sig_init,
    # Numerical estimate parameters
    scheme, steps, h, discard, gap)


X = complex(X)

plot(X[1,1:end÷8000:end],ms=1,".")
plot(X[1,1:8000],ms=1,".")

data = Dict("sigma"         => sigma,
            "V_prime_str"   => "x -> -x.*(x.^2 .- 1)",
            "sig_init"      => sig_init,
            # Numerical estimate parameters
            "scheme"        => scheme,
            "steps"         => steps,
            "h"             => h,
            "discard"       => discard,
            "gap"           => gap,
            "X"             => X)
# save("Examples/Nonlinear Langevin/data/data_11_12_2020.jld",data)

# data = load("Examples/Nonlinear Langevin/data/data_10_23_2020.jld")
# X = data["X"]

# auto_times(X[1,:])

# Put in Psi functions
Psi(x) = [x; x.^3]

# Model reduction Parameters
M_out = 50
ty = "bin"

### Varing parameters
###       xspect_est , par    , nfft    , n    , p
#
Parms = [["DM"       , 5000  , 2^17    , 2    , 5],
         ["SP"       , 5000  , 2^17    , 2    , 5]]

nfft = Parms[1][3]

P = 2#length(Parms)

h_wf_packs  = []
times = zeros(P)
for i = 1:P
    Out = @timed get_wf(X, Psi;
        M_out, ty, info = true,
        xspec_est = Parms[i][1],
        par       = Parms[i][2],
        nfft      = Parms[i][3],
        n         = Parms[i][4],
        p         = Parms[i][5]);

    append!(h_wf_packs,Out.value)
    times[i]      = Out.time
end

h_wf_dm = h_wf_packs[1]
h_wf_sp = h_wf_packs[8]

h_wf_dm[:,:,1]
h_wf_sp[:,:,1]

output = Dict("h_wf_packs" => h_wf_packs)
save("Examples/Nonlinear Langevin/data/data_11_12_2020.jld",merge(data,output))
