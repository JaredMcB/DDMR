##----------------------------------------------------------------------------
## etdrk.jl

## Exponential RK4 scheme

## This is 4th-order in the deterministic case, weakly 1st
## order in the stochastic case.  I learned the idea from
## Jonathan Goodman, though he also said he learned it from
## Mike Shelley, and that it was already known.

## It is scheme ETD4RK in [Cox and Matthews, JCP 176 (2002)
## 430--455]

## Unlike sx2kse.jl, this is written to be generally
## applicable to any system for which the linear part is
## diagonal, e.g., viscous Burgers equation in spectral
## variables.

module etdrk

Complex128 = Complex{Float64}

######################################################
## General ETDRK4 solver

export   make_etdrk4_stepper
function make_etdrk4_stepper(eval_nonlin!::Function,
                             spec,
                             dt)

    ## allocate temporary storage
    N  = length(spec)
    a  = zeros(Complex128,N)
    b  = zeros(Complex128,N)
    c  = zeros(Complex128,N)
    F  = zeros(Complex128,N)
    Fa = zeros(Complex128,N)
    Fb = zeros(Complex128,N)
    Fc = zeros(Complex128,N)

    ## precompute coefficients
    expv1 = exp.(spec*dt)
    expv2 = exp.(0.5*spec*dt)
    gv2   = 0.5*dt*G.(0.5*spec*dt)
    hv1   = dt*H1.(dt*spec)
    hv2   = dt*H2.(dt*spec)
    hv3   = dt*H3.(dt*spec)

    ## temporary storage
    V = zeros(Complex128,N)

    function stepper(U)
        stepper(U,V)
        return V
    end

    function stepper(U, V)

        eval_nonlin!(U, F)

        for k=1:N
            a[k] = expv2[k] * U[k] + gv2[k] * F[k]
        end

        eval_nonlin!(a,Fa)

        for k=1:N
            b[k] = expv2[k] * U[k] + gv2[k] * Fa[k]
        end

        eval_nonlin!(b,Fb)

        for k=1:N
            c[k] = expv2[k] * a[k] + gv2[k] * (2.0*Fb[k] - F[k])
        end

        eval_nonlin!(c,Fc)

        for k=1:N
            V[k] = ( expv1[k] * U[k] +
                     F[k] * hv1[k] +
                     2 * (Fa[k] + Fb[k]) * hv2[k] +
                     Fc[k] * hv3[k] )
        end
    end
     
    function stepper(U, nsteps::Number)
        stepper(U,nsteps,V)
        return V
    end
        
    function stepper(U, nsteps::Number, V)
        stepper(U,V)
        for n=2:nsteps
            stepper(V,V)
        end
    end
        
    return stepper
end


##--------------------------------
## Helper functions

## The ETDRK methods require various helper functions, all
## analytic functions.  See, e.g., [Cox-Matthews].  There
## are explicit expressions for all of the, but because of
## cancellations, the exact expressions may not be
## numerically accurate.  In such cases, it's better to
## evaluate the functions by e.g. contour
## integration. 

## Here we automatically switch between exact formula and
## interpolation when necessary; interpolation data is
## generated by contour integration.  Note this may well be
## an overkill: Kassam and Trefethen just used 16 points,
## which seems sufficient.  Also, some of the machinery
## below was written to support adaptive timestepping.
function tabulate(f::Function;
                  n::Int64 = 20000,
                  a::Float64 = -1.0,
                  b::Float64 = +1.0)

    h      = (b-a)/n
    grid   = [a+i*h for i=0:n]
    fgrid  = map(z->circle_mean(f,z), grid)
    dfgrid = map(z->circle_mean_diff(f,z), grid)

    function finterp(x::Float64)
        i = floor(Int,(x-a)/h) + 1

        if 1 <= i <= n
            return polyinterp_eval(x,
                                   grid[i], grid[i+1],
                                   fgrid[i], dfgrid[i],
                                   fgrid[i+1], dfgrid[i+1])
        else
            return f(x)
        end
    end

    finterp
end


## Cubic interpolation using endpoint values and
## derivatives.
function polyinterp_eval(x::Float64,
                         a::Float64, b::Float64,
                         fa::Float64, dfa::Float64,
                         fb::Float64, dfb::Float64)
    h = b-a
    y = (x-a)/h
    A = fa
    B = dfa*h
    C = 3*(fb - fa) - h*(2*dfa + dfb)
    D = -2*(fb - fa) + h*(dfb + dfa)

    A + y*(B + y*(C + y*D))
end

## Adaptively compute contour integrals.
function circle_mean(f::Function, z;
                     eps=1e-12, n0=32, nmax=4096)
    let a = circle_mean_1(f, z, n=n0),
        n = 2*n0,
        b = circle_mean_1(f, z, n=n),
        count = 0
        while abs(a-b) > eps*(1.0+max(abs(a),abs(b))) && n <= nmax
            count += 1
            n *= 2
            a  = b
            b  = circle_mean_1(f, z, n=n)
        end
        if n > nmax
            warn("circle_mean(): $nmax points reached; ; resid=$(abs(a-b)) > $eps ($(abs(a-b)/max(abs(a),abs(b))))")
        end
        return b
    end
end

## Contour integration around a circle by the trapezoid
## rule, taking care to keep the contour away from 0.
function circle_mean_1(f::Function, z;
                       n::Int64=32, r::Float64=2.0)
    dt::Float64 = pi/n

    if abs(z-r) < 0.5 || abs(z+r) < 0.5
        r += 1
    end
    
    sum::Complex128 = 0.0+0.0im
    for i=1:(n-1)
        sum += f(z+r*exp(im*i*dt))
    end

    (real(sum) + 0.5*(f(z-r) + f(z+r))) / n
end

## Adaptively compute differences of contour integrals.
function circle_mean_diff(f::Function, z;
                          eps=1e-12, n0=32, nmax=4096)
    let a = circle_mean_diff_1(f, z, n=n0),
        n = 2*n0,
        b = circle_mean_diff_1(f, z, n=n)
        while abs(a-b) > eps*(1.0+max(abs(a),abs(b))) && n <= nmax
            n *= 2
            a  = b
            b  = circle_mean_diff_1(f, z, n=n)
        end
        if n > nmax
            warn("circle_mean_diff(): $nmax points reached; resid=$(abs(a-b)) > $eps ($(abs(a-b)/max(abs(a),abs(b))))")
        end
        return b
    end
end

## Compute contour integrals.
function circle_mean_diff_1(f::Function, z;
                            n::Int64=32, r::Float64=2.0)
    dt::Float64 = pi/n

    if abs(z-r) < 0.5 || abs(z+r) < 0.5
        r += 1
    end
    
    sum::Complex128 = 0.0+0.0im
    for i=1:(n-1)
        c = r*exp(im*i*dt)
        sum += f(z+c) / c
    end

    (real(sum) + 0.5*(-f(z-r)/r + f(z+r)/r)) / n
end


## specific helper functions
println("# constructing ETDRK helpfer functions...")
flush(stdout)

@time H1 = tabulate(z->(-4 - z + exp(z) * (4 - 3*z + z^2 ))/z^3, a=-2., b=2., n=40000)
@time H2 = tabulate(z->(2 + z + exp(z) * (-2+z))/z^3, a=-2., b=2., n=40000)
@time H3 = tabulate(z->(-4 - 3*z - z^2 + exp(z) * (4-z))/z^3, a=-2., b=2., n=40000)
@time G  = tabulate(z->(exp(0.5*z)-1)/z)
# H = tabulate(z->(exp(z)-1-z)/z^2)


##------------------------------------------------------
end #module
