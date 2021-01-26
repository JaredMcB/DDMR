"""
Title: myKSE_field.jl
author: Jared McBride (26 Jan 2021; American Fork, Utah)

This code is a modulizes the RHS of the KSE ODE in Fourier space. The purpose
being to feed it in to Dr. Lins, KSE solver and see what happens.

This code is meant to fit into the framework of Dr. Lin's KSE solver.

This code attempts to CORRECT for
aliasing.

"""

module myKSE_field

using FFTW

function make_myKSE_field(N; alpha=1.0, beta=1.0, L=2*pi,
                       dispersion = v->alpha*v^2-beta*v^4)

    ## function to evaluate nonlinear term
    q = 2π/L*(1:N)
    L = dispersion.(q)
    ℓ = -0.5im*q

    K = 3N + 1
    v_pad = zeros(ComplexF64,K)
    Fp = plan_fft(v_pad)
    iFp = plan_bfft(v_pad)

    function ks_field!(U,F)
        v_pad[2:N+1]        = U
        v_pad[end-N+1:end]  = reverse(conj(U),dims = 1)
        nv = Fp*(real(iFp*(v_pad)).^2)/K
        F[:] = ℓ .* nv[2:N+1] + L.*U
    end
end

end # module myKSE_field




pad = n
K = 3n+1
NonLinNA = function (v)
    v_pad = [v[1:n+1]; zeros(pad);v[n+2:N]]
    nv = fft(bfft(v_pad).^2)/K
    Nv_dealiased = ℓ .* [nv[1:n+1]; nv[end-n+1:end]]
    # ifftshift(conv(fftshift(v),fftshift(v))[N-(n-1):N+n])/N
    # v_pad = [v[1:n]; zeros(pad);v[n+1:N]]
    # nv = F*(real(iF*v_pad)).^2*K/N
    # [nv[1:n]; nv[end-n+1:end]]
end