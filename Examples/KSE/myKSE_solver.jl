"""
Title: myKSE_solver.jl
author: Jared McBride (18 Jan 2021; American Fork, Utah)

After several weeks during the holidays to produce alias free solutions to KSE
using the frame work of Kassam and Trefethen (found in FOURTH-ORDER
TIME-STEPPING FOR STIFF PDEs∗, 2005) I started again with a different approach.

This code relies on myODE_solver.jl with I made and tested just prior to making
this file.


"""

module myKSE_solver

using FFTW

mos = include("myODE_solver.jl")
mETD = include("myETDRK4_scheme.jl")

function my_KSE_solver(
    T :: Real = 150;    # Length (in seconds) of time of run
    P :: Real = 32π,    # Period
    n :: Int64 = 64,    # Number of linearly independent fourier modes used (beyond 0)
    h :: Real = 1/4,    # Timestep
    g = x -> cos(x/16)*(1 + sin(x/16)),     # Initial condition function
    T_disc = T/2,
    n_gap = 100,        # 1 +  No. of EDTRK4 steps between reported data
    )

    N = 2n+1

    ## Spatial grid and initial conditions:
    x = P*(0:N-1)/N
    u = g.(x)
    v = fft(u)/N        # The division by N is to effect the DFT I want.

    ## Now we set up the equations
    # dv_k/dt = (q^2_k - q^4_k)*v_k - i*q_k/2*(convolution) for k = -n:n
    q = 2π/P*[0:n; -n:-1]

    # (diagonal) Linear part as vector
    L = q.^2 - q.^4

    # Nonlinear part
    ℓ = -0.5im*q

    K = 3n + 1
    v_pad = zeros(ComplexF64,K)
    Fp = plan_fft(v_pad)
    iFp = plan_bfft(v_pad)

    function NonLin(v)
        v_pad[2:n+1]        = v[2:n+1]
        v_pad[end-n+1:end]  = v[n+2:end]
        nv = Fp*(real(iFp*(v_pad)).^2)/K
        return ℓ .* [nv[1:n+1];nv[end-n+1:end]]
    end




    ## Now we Now we use the solver
    scheme = mETD.scheme_ETDRK4

    F_etd = [L, NonLin]

    steps   = ceil(Int,T/h)
    discard = ceil(Int,T_disc/h)

    vv = mos.my_ODE_solver(scheme,v;
        F = F_etd,
        steps,
        discard,
        h,
        gap = n_gap)
end

end #module
