
using FFTW
using LinearAlgebra
using DSP: conv, nextfastfft
using Polynomials
using StatsBase
using SparseArrays

include("modgen_LSDE.jl")
include("..\\..\\Tools\\Model_Reduction_Dev.jl")

using JLD
using PyPlot

A       = reshape([-0.5],1,1)
σ       = reshape([1],1,1)
Xo      = [1]
t_disc  = 1000
gap     = 10
scheme  = "EM"
d       = size(A,1)
t_start = 0
t_stop  = 1e6
h       = 1e-2
Δt      = h*gap
M_out   = 100

@time X = modgen_LSDE(t_start,t_stop,h,
    A = A,
    σ = σ,
    Xo = Xo,
    t_disc = t_disc,
    gap = gap,
    scheme = scheme)

N       = size(X,2)
nfft    = nextfastfft(N)
X = [X zeros(d,nfft - N)]

τ_exp, τ_int    = auto_times(X[:])*Δt
N_eff           = N*Δt/τ_int

Psi(x) = x

## Get_wf

signal = X
Psi    = Psi
M_out  = 20
n      = 3
p      = 1500
par    = 1500
rl     = true
PI     = false
rtol   = 1e-6
# We would like a presample since we want the
# times series to be offset by one.

sig = signal[:,2:end]
d, steps = size(sig)
nu = size(Psi(zeros(d,1)),1)

pred = complex(zeros(nu, steps))
for n = 1:steps
    pred[:,n] = Psi(signal[:,n])
end

# h_wf = vector_wiener_filter_fft(pred, sig, M_out,
#         n = n, p = p, par = par, PI = PI, rtol = rtol)
#
# h_wf = rl ? real(h_wf) : h_wf

## vector_wiener_filter_fft

sig     = signal[:,1:end-1]
pred    = pred
M_out   = 20
par     = 1500
win     = "Par"
n       = 3
p       = 1500
PI      = true
rtol    = 1e-6

d, stepsy = size(sig)
nu, stepsx = size(pred)

stepsx == stepsy || print("X and Y are not the same length. Taking min.")
steps = minimum([stepsx stepsy])
nfft = nextfastfft(steps)
nffth = Int(floor(nfft/2))

L = par
lags = -L:L

# Smoothed viewing window
lam = _window(L, win = win, two_sided = false)

R_pred_smoothed = zeros(Complex,nu,nu,length(0:L))
for i = 1 : nu
    for j = 1 : nu
        temp = my_crosscov(pred[i,1:steps],pred[j,1:steps],lags)
        temp = .5*(temp[L+1:end] + conj(reverse(temp[1:L+1])))
        R_pred_smoothed[i,j,:] = lam .* temp
    end
end

### Breaking in:
tmp_R = R_pred_smoothed[:]
tmp_R_ana = map(x -> (1+h*A[1,1])^(gap*x),0:L)
plot((0:L)*Δt,[tmp_R tmp_R_ana])
# right on the money

NN_ckms = map(x-> floor(Int, 10^x),2:.25:4)
LL = complex(zeros(1,1,L+1,length(NN_ckms)))
for i in 1:length(NN_ckms)
    LL[:,:,:,i] = spectfact_matrix_CKMS(R_pred_smoothed,
        N_ckms = NN_ckms[i])
end
plot(LL[1,1,:,:])
    
Norm = map(i -> norm(LL[1,1,:,9] .- LL[1,1,:,i],Inf),1:9)
loglog(NN_ckms, Norm)





###

# Compute coefficients of spectral factorization of z-spect-pred
l = PI ? spectfact_matrix_CKMS_pinv(R_pred_smoothed,rtol = rtol) :
         spectfact_matrix_CKMS(R_pred_smoothed)

l_pad_minus = nfft >= L+1 ? cat(dims = 3,l,zeros(nu,nu,nfft - L - 1)) :
                           l[:,:,1:nfft]

z_spect_pred_minus_num_fft = fft(l_pad_minus,3)
z_spect_pred_plus_num_fft = zeros(Complex,nu,nu,nfft)
for i = 1 : nfft
    z_spect_pred_plus_num_fft[:,:,i] = z_spect_pred_minus_num_fft[:,:,i]'
end

# Compute z-cross-spectrum of sigpred
z_crossspect_sigpred_num_fft = z_crossspect_fft(sig, pred,
                    nfft = nfft, n = n, p = p, win = "Par");

# This computes the impule response (coefficeints of z) for S_{yx}{S_x^+}^{-1}
S_sigpred_overS_plus_fft_num = complex(zeros(d,nu,nfft))

for i = 1 : nfft
    S_sigpred_overS_plus_fft_num[:,:,i] = z_crossspect_sigpred_num_fft[:,:,i]/
                                          z_spect_pred_plus_num_fft[:,:,i]
end

S_sigpred_overS_plus_fft_num_fft = ifft(S_sigpred_overS_plus_fft_num,3)

# Extracts causal part coefficinets of S_{yx}{S_x^+}^{-1}, {S_{yx}{S_x^+}^{-1}}_+
S_sigpred_overS_plus_fft_plus_num_fft = cat(dims = 3,
                S_sigpred_overS_plus_fft_num_fft[:,:,1: nffth],
                zeros(d,nu,nfft - nffth))

# Computes causal part of S_{yx}/S_x^+, {S_{yx}/S_x^+}_+
S_sigpred_overS_plus_plus_num_fft = fft(S_sigpred_overS_plus_fft_plus_num_fft,3);

# Obtain transfer function H by dividing {S_{yx}/S_x^+}_+ by S_x^-

H_num = complex(zeros(d,nu,nfft))
for i = 1: nfft
    H_num[:,:,i] = S_sigpred_overS_plus_plus_num_fft[:,:,i]/
                   z_spect_pred_minus_num_fft[:,:,i]
end

# Extrct tranferfunction coeffifcients (impulse responce of Weiner filter)
h_num_raw = ifft(H_num, 3)

# Truncate
M_out > nfft && println("M_out > nfft, taking min")
M = min(M_out, nfft)
h_wf = h_num_raw[:,:,1:M]
h_wf = real(h_wf)


##Scratch
Δt*(I+A)

N = size(X,2)
X_hat = zeros(d,N); X_hat[:,1] = X[:,1]
for i=2:N
    X_hat[:,i] = sum(h_wf[:,:,k]*X_hat[:,i-k] for k = 1:min(i-1,M_out),dims = 2)
    isnan(X_hat[1,i]) && break
end
X_hat
for i = 1:100
    println(X_hat[:,i]')
end