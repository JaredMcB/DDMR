"""
Today we will investigate:
The locality of the wiener filter

"""


using Plots
ENV["MPLBACKEND"]="qt5agg" # Change backend to allow output plots
pyplot()


include("..\\..\\Matrix Wiener Filter\\wiener_filter_Matrix_fft.jl")
include("..\\DataGen.jl")

## Preference parameters
t_start = 0
t_stop = 10^4
steps = 10^6 + 1 # (this includes the t_stop)
discard = 10^4
steps_tot = steps + discard

sig_init = [1.5]
sigma = [.2]
sigma_v = sigma
d = 1

Nen = 10
lag = 0:999
bN = 10


dVdx(x) = -x.*(x.^2 .- 1) # Symetric Double well
# dVdx(x) = -(6x.^5 - 8x.^3 + 2x)
Psi(x) = [x; x.^3]

M_out = 20

# Derivitive parameters
steps_tot = steps + discard
nu = size(Psi(zeros(d,1)),1)
dt = (t_stop - t_start)/(steps - 1)
tim = range(t_start,t_stop,length = steps)

## Code begins

## Autocorrelation FUnction of the Solution

Autoc =  Autocov(steps,
    lag = lag,
    bN = bN,
    scheme = "FE",
    t_start = t_start,
    t_stop = t_stop,
    discard = discard,
    sig_init = sig_init,
    sigma = sigma,
    V_prime = x -> -x.*(x.^2 .- 1),
    vari = true)

## Autocorrelation of the reduced model generated by mean filter

h_ens = Run_and_get_WF_DWOL(
    Psi,
    scheme = "FE",
    steps = steps,
    t_start = t_start,
    t_stop = t_stop,
    discard = discard,
    sig_init = sig_init,
    sigma = sigma,
    d = d,
    V_prime = dVdx,
    Nen = Nen,
    M_out = 20)

h_mean = analyse_h_ens(h_ens)

# h_mean[3]
# h_var = h_mean[2]
h_m = h_mean[1]

Autoc_h_m = Autocov(h_m, Psi, steps,
    lag = lag,
    bN = bN,
    t_start = t_start,
    t_stop = t_stop,
    discard = discard,
    sig_init = sig_init,
    sigma = sigma,
    V_prime = x -> -x.*(x.^2 .- 1),
    vari = true)

# x= -3:.01:3
# plot(x,[x .- dt*(x.^3 .- x) map(x -> h_m[1,:,1]'*Psi(x),x)])
## Autocovariance a single h_wf
signal = DataGen_DWOL(steps,
    scheme = "FE",
    t_start = t_start,
    t_stop = t_stop,
    discard = discard,
    sig_init = sig_init,
    sigma = sigma,
    V_prime = x -> -x.*(x.^2 .- 1),
    SM1 = true,
    Obs_noise = false)

h_wf = get_wf(signal,Psi)

Autoc_h_wf = Autocov(h_wf,Psi,steps,
    lag = lag,
    bN = bN,
    t_start = t_start,
    t_stop = t_stop,
    discard = discard,
    sig_init = sig_init,
    sigma = sigma,
    V_prime = x -> -x.*(x.^2 .- 1),
    vari = true)

## Plot the trhee autocovariances

plot(lag, [Autoc[1] Autoc_h_m[1] Autoc_h_wf[1]],
    xlabel = "lag",
    label = ["True" "mean" "single"],
    line =(3,[:solid :dash :dot]))


h_trunc = VarTrunc(h_wf)

A = zeros(length(lag),M_out)
for i = 1:5
    A[:,i] = Autocov(h_trunc[:,:,:,i],Psi,steps,
        lag = lag,
        bN = bN,
        t_start = t_start,
        t_stop = t_stop,
        discard = discard,
        sig_init = sig_init,
        sigma = sigma,
        V_prime = x -> -x.*(x.^2 .- 1),
        vari = false)
end
A
plot!(lag,A[:,1:5])


## Repreduced Model Information
