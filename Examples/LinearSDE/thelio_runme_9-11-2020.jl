include("modgen_LSDE.jl")
include("../../Tools/Model_Reduction_Dev.jl")

# include("..\\..\\Tools\\Model_Reduction_Dev.jl")

using JLD
using Dates
using Random
gen     = 2

A       = reshape([-0.5],1,1)
σ       = reshape([1],1,1)
Xo      = [1]
t_disc  = 1000
gap     = 10
d       = size(A,1)
t_start = 0
t_stop  = 5e4
h       = 1e-2
Δt      = h*gap

function runner(;
    A       = reshape([-0.5],1,1),
    σ       = reshape([1],1,1),
    Xo      = [1],
    t_disc  = 1000,
    gap     = 10,
    d       = size(A,1),
    t_start = 0,
    t_stop  = 1e5,
    h       = 1e-2,
    Δt      = h*gap,
    M_out   = 100,
    seed    = zeros(UInt32,4)
    )

    if seed == zeros(UInt32,4)
        seed = Random.seed!().seed
    else
        Random.seed!(seed)
    end

    println("===========M_out = $M_out===========")
    println("Time to get data: ")
    @time X = modgen_LSDE(t_start,t_stop,h,
        A = A,
        σ = σ,
        Xo = Xo,
        t_disc = t_disc,
        gap = gap)

    N       = size(X,2)
    nfft    = nextfastfft(N)
    X = [X zeros(d,nfft - N)]

    τ_exp, τ_int    = auto_times(X[:])*Δt
    N_eff           = N*Δt/τ_int
    N_disc          = t_disc/Δt
    N_disc_rec      = 20*τ_exp/Δt

    println("About data: N_eff = $N_eff, tau_int = $τ_int, tau_exp = $τ_exp")
    println("N_disc = $N_disc, tau_exp = $τ_exp, 20*tau_exp = $N_disc_rec")
    println("-------------------------------")
    println("Time to get h_wf: ")
    Psi(x) = x
    @time h_wf = get_wf(X,Psi, M_out = M_out)

    nu    = size(Psi(X[:,1]),1)

    X_rm = zeros(d,N); X_rm[:,1:M_out] = X[:,1:M_out]

    PSI = zeros(nu,N);
    for i = 1:M_out
        PSI[:,i] = Psi(X_rm[:,i])
    end

    for i = M_out + 1 : N
        X_rm[:,i] = sum(h_wf[:,:,k]*PSI[:,i-k] for k = 1:M_out, dims = 2) + sqrt(h)*σ*randn(d)
        PSI[:,i] = Psi(X_rm[:,i])
        isnan(X_rm[1,i]) && break
    end

    lags = 0:1000

    A_rm = my_autocor(X_rm[:],lags)
    A    = my_autocor(X[:],lags)
    return A, A_rm, seed
end

## Now for the repeated runs


MM_out = [2,4,6,10,15,20,100]


regs = length(MM_out)
reps = 10
its = regs*reps

AA = AA_rm = zeros(its,1001)
Seeds = zeros(UInt32,its,4)


for i in 1:regs
    for j in 1:reps
        output = runner(M_out = MM_out[i],seed = Seeds[j,:])
        AA[(i-1)*reps + j,:] = output[1]
        AA_rm[(i-1)*reps + j,:] = output[2]
    end
end

data = Dict(
        "A" => A,
        "σ" => σ,
        "Xo" => Xo,
        "t_disc" => t_disc,
        "gap" => gap,
        "t_start" => t_start,
        "t_stop" => t_stop,
        "h" => h,
        "MM_out" => MM_out,
        "AA" => AA,
        "AA_rm" => AA_rm,
        "Seeds" => Seeds,
        "tm" => now())

save("/u5/jaredm/data/LSDE_Data/WFCeofvAutocor_9-11_gen$gen.jld", "data", data)
# save("c:\\Users\\JaredMcBride\\Desktop\\DDMR\\Examples\\LinearSDE\\LSDE_Data\\WFCeofvAutocor.jld", "data", data)
