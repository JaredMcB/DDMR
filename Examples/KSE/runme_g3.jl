include("KSE_modredrun.jl")

## Parameters for KSE model
gen = 3
T = 16000 # Length (in seconds) of time of run
T_disc = 1000 # Length (in seconds) of time discarded
P = 32π  # Period
N = 128  # Number of fourier modes used
h = 1e-3 # Timestep
g = x -> cos(π*x/16)*(1 + sin.(π*x/16))
q = 2π/P*(0:N-1)
obs_gap = 100
d = 5 # No. of lowest modes taken in reduced model
M_out = 1024 # No. of coeficinets in Wiener filter output
Nex = 1024

### First run #########################################
KSE_modredrun(
   gen = gen,
   T = T, # Length (in seconds) of time of run
   T_disc = T_disc, # Length (in seconds) of time discarded
   P = P,  # Period
   N = N,  # Number of fourier modes used
   h = h, # Timestep
   g = g,
   q = q,
   obs_gap = obs_gap,
   d = d, # No. of lowest modes taken in reduced model
   M_out = M_out,
   Nex = Nex,
   short = false,
   loadsol = false,
   loadwf = false)

### Second run ##############################################
M_out = 100

KSE_modredrun(
   gen = gen,
   T = T, # Length (in seconds) of time of run
   T_disc = T_disc, # Length (in seconds) of time discarded
   P = P,  # Period
   N = N,  # Number of fourier modes used
   h = h, # Timestep
   g = g,
   q = q,
   obs_gap = obs_gap,
   d = d, # No. of lowest modes taken in reduced model
   M_out = M_out,
   Nex = Nex,
   short = false,
   loadsol = true,
   loadwf = false)

### third run ##############################################
M_out = 20

KSE_modredrun(
   gen = gen,
   T = T, # Length (in seconds) of time of run
   T_disc = T_disc, # Length (in seconds) of time discarded
   P = P,  # Period
   N = N,  # Number of fourier modes used
   h = h, # Timestep
   g = g,
   q = q,
   obs_gap = obs_gap,
   d = d, # No. of lowest modes taken in reduced model
   M_out = M_out,
   Nex = Nex,
   short = false,
   loadsol = true,
   loadwf = false)
