##########################################
#
# file: WF_matpreds.jl
# author; Jared McBride (7/21/2020)
#
# In this file are functions relate to Wiener
# projection model reduction in whihc the pred-
# ictors are matrix-valued rather then the trad-
# itional vector-valued case.
#
################################################
#
# Here we find the Wiener filter for two scalar
# processes, the signal and the predictors (or
# observations).
# The inputs are
#   sig : the timeseries we are approximating
#   pred : the timeseries with which we will
#       be approximating the signal.
#   M : the degree of the approximating Laurent
#       polynomials used in construction of the
#       spectra.
# The output is
#   h : the sequence of length 2M+1.
#
##############################################
# Spectral Method

using LinearAlgebra
using StatsBase
using FFTW

# First thing we need is a z-spect estimator
function z_crossspect_fft(
    pred::Array{Complex{Float64},3},
    sig::Array{Complex{Float64},2};
    L = 50,
    Nex = 2^10,
    win = "Par")

    ## pred = d x nu x steps, sig = d x steps
    d, stepsx = size(sig)
    dp, nu, stepsy = size(pred)

    d == dp || error("first dimension of pred should equal dimension of sig.")

    Nexh = Int(floor(Nex/2))
    lags = -L:L;

    stepsx == stepsy || print("sig and pred are not the same length. Taking min.")
    steps = minimum([stepsx stepsy])

    # Smoothed viewing window
    if win == "Bar"
        lam = 1 .- (0:L)/L
    elseif win == "Tuk"
        lam = .5*(1 .+ cos.(pi/L*(0:L)))
    elseif win == "Par"
        LL = Int(floor(L/2))
        lam1 = 1 .- 6*((0:LL)/L).^2 .+ 6*((0:LL)/L).^3
        lam2 = 2*(1 .- (LL+1:L)/L).^3
        lam = [lam1; lam2]
    else
        lam = ones(L+1)
    end
    Lam = [lam[L+1:-1:2]; lam]

    C_smoothed = zeros(nu,length(lags))
    for i = 1 : nu
        C_smoothed[i,:] = Lam .* sum([crosscov_con(pred[k,i,:],sig[k,:],lags) for k = 1:d])
    end

    ## C_smoothed = d x 2L+1

    ## Pad with zeros in preparation for fft
    C_padded = cat(dims = 2, zeros(nu,Nex - Nexh - L), C_smoothed, zeros(nu,Nexh - L - 1))
    C = fftshift(C_padded,2)

    z_crossspect_num_fft = fft(C,2);
end

function Matrix_CKMS_c(P)
    d = size(P)[1];
    m = size(P)[3] - 1

    NN = reverse(P[:,:,2:end],dims = 3)
    Re = Rr = p0 = P[:,:,1]

    F = [[zeros(d,d*(m-1)); I] zeros(d*m,d)]
    h = [zeros(d,d*(m-1)) I]

    K = complex(zeros(d*m,d))
    for i = 0 : m-1
        K[d*i + 1: d*(i+1),:] = NN[:,:,i+1]
    end
    L = K

    for i = 1:200
        hL = h*L; FL = F*L

        K_new = K - FL/Rr*hL'
        L_new = FL - K/Re*hL
        Re_new = Re - hL/Rr*hL'
        Rr_new = Rr - hL'/Re*hL

        K = K_new
        L = L_new
        Re = Re_new
        Rr = Rr_new
    end

    k = K/Re
    re = Re

    sqrt_re = sqrt(re)

    l = complex(zeros(d,d,m+1))
    l[:,:,1] = sqrt_re;
    for i = m-1:-1:0
        l[:,:,m-i+1] = k[d*i + 1: d*(i+1),:]*sqrt_re
    end
    l
end

function vector_wiener_filter_fft(pred::Array{Float64,3},
    sig::Array{Float64,2},
    M_out = 20;
    par::Int64 = 55,
    Nex::Int64 = 2^10,
    win = "Par"
    )

    d, stepsy = size(sig)
    dp, nu, stepsx = size(pred)

    d == dp || error("first dimension of pred should equal dimension of sig.")

    stepsx == stepsy || print("X and Y are not the same length. Taking min.")
    steps = minimum([stepsx stepsy])

    Nexh = Int(floor(Nex/2))

    L = par
    lags = 0:L;

    # Smoothed viewing window
    if win == "Bar"
        lam = 1 .- (0:L)/L
    elseif win == "Tuk"
        lam = .5*(1 .+ cos.(pi/L*(0:L)))
    elseif win == "Par"
        LL = Int(floor(L/2))
        lam1 = 1 .- 6*((0:LL)/L).^2 .+ 6*((0:LL)/L).^3
        lam2 = 2*(1 .- (LL+1:L)/L).^3
        lam = [lam1; lam2]
    else
        lam = ones(L+1)
    end

    R_pred_smoothed = zeros(nu,nu,length(lags))
    for i = 1 : nu
        for j = 1 : nu
            R_pred_smoothed[i,j,:] = lam .* sum([my_crosscov(pred[k,i,:],pred[k,j,:],lags) for k = 1:d])
        end
    end

    # Compute coefficients of spectral factorization of z-spect-pred
    l = Matrix_CKMS_c(R_pred_smoothed);

    l_pad_minus = cat(dims = 3,l,zeros(nu,nu,Nex - L - 1))

    z_spect_pred_minus_num_fft = fft(l_pad_minus,3)
    z_spect_pred_plus_num_fft =complex(zeros(nu,nu,Nex))
    for i = 1 : Nex
        z_spect_pred_plus_num_fft[:,:,i] = z_spect_pred_minus_num_fft[:,:,i]'
    end

    # Compute z-cross-spectrum of sigpred
    z_crossspect_predsig_num_fft = z_crossspect_fft(pred,sig, L = par, Nex = Nex, win = "Par");

    # This computes the impule response (coefficeints of z) for S_{yx}{S_x^+}^{-1}
    S_predsig_overS_plus_fft_num = complex(zeros(nu,Nex))
    for i = 1: Nex
        S_predsig_overS_plus_fft_num[:,i] = z_spect_pred_plus_num_fft[:,:,i]\z_crossspect_predsig_num_fft[:,i]
    end

    S_predsig_overS_plus_fft_num_fft = ifft(S_predsig_overS_plus_fft_num,2)

    # Extracts causal part coefficinets of S_{yx}{S_x^+}^{-1}, {S_{yx}{S_x^+}^{-1}}_+
    S_predsig_overS_plus_fft_plus_num_fft = cat(dims = 2,S_predsig_overS_plus_fft_num_fft[:,1: Nexh], zeros(nu,Nex - Nexh))

    # Computes causal part of S_{yx}/S_x^+, {S_{yx}/S_x^+}_+
    S_predsig_overS_plus_plus_num_fft = fft(S_predsig_overS_plus_fft_plus_num_fft,2);

    # Obtain transfer function H by dividing {S_{yx}/S_x^+}_+ by S_x^-

    H_num = complex(zeros(nu,Nex))
    for i = 1: Nex
        H_num[:,i] = z_spect_pred_minus_num_fft[:,:,i]\S_predsig_overS_plus_plus_num_fft[:,i]
    end

    # Extrct tranferfunction coeffifcients (impulse responce of Weiner filter)
    h_num_raw = ifft(H_num,2)

    # Truncate
    h_num_fft = h_num_raw[:,1:M_out]

    h_num_fft[:,1]
    h_wf = h_num_fft
end
