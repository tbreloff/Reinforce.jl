module PendulumEnv
# Ported from: https://github.com/openai/gym/blob/996e5115621bf57b34b9b79941e629a36a709ea1/gym/envs/classic_control/pendulum.py
#              https://github.com/openai/gym/wiki/Pendulum-v0

using Reinforce: AbstractEnvironment
using LearnBase: IntervalSet
using RecipesBase
using Distributions
using Random: seed!

import Reinforce: reset!, actions, finished, step!, state

export
  Pendulum,
  reset!,
  step!,
  actions,
  finished,
  state

const max_speed = 8.0
const max_torque = 2.0

angle_normalize(x) = ((x+π) % (2π)) - π

mutable struct PendulumState{T<:AbstractFloat} <: AbstractVector{T}
  θ::T
  θvel::T
end

PendulumState() = PendulumState(0., 0.)

Base.size(::PendulumState) = (2,)

function Base.getindex(s::PendulumState, i::Int)
  (i > length(s)) && throw(BoundsError(s, i))
  ifelse(i == 1, s.θ, s.θvel)
end

function Base.setindex!(s::PendulumState, x, i::Int)
  (i > length(s)) && throw(BoundsError(s, i))
  setproperty!(s, ifelse(i == 1, :θ, :θvel), x)
end

mutable struct Pendulum{V<:AbstractVector} <: AbstractEnvironment
  state::V
  reward::Float64
  a::Float64 # last action for rendering
  steps::Int
  maxsteps::Int
end

Pendulum(maxsteps = 500) = Pendulum(PendulumState(),0., 0., 0, maxsteps)

function reset!(env::Pendulum)
  env.state = PendulumState(rand(Uniform(-π, π)), rand(Uniform(-1., 1.)))
  env.reward = 0.0
  env.a = 0.0
  env.steps = 0
  env
end

actions(env::Pendulum, s) = IntervalSet(-max_torque, max_torque)

function step!(env::Pendulum, s, a)
  θ, θvel = env.state
  g = 10.0
  m = 1.0
  l = 1.0
  dt = 0.05

  env.a = a
  a = clamp(a, -max_torque, max_torque)
  env.reward = -(angle_normalize(θ)^2 + 0.1θvel^2 + 0.001a^2)

  # update state
  newθvel = θvel + (-1.5g/l * sin(θ+π) + 3/(m*l^2)*a) * dt
  newθ = θ + newθvel * dt
  newθvel = clamp(newθvel, -max_speed, max_speed)
  env.state = PendulumState(newθ, newθvel)

  env.steps += 1
  env.reward, env.state
end


function state(env::Pendulum)
  θ, θvel = env.state
  Float64[cos(θ), sin(θ), θvel]
end

finished(env::Pendulum, s′) = env.steps >= env.maxsteps

# ------------------------------------------------------------------------

@recipe function f(env::Pendulum)
  legend := false
  xlims := (-1,1)
  ylims := (-1,1)
  grid := false
  ticks := nothing

	# pole
  @series begin
    w = 0.2
    x = [-w,w,w,-w]
    y = [-.1,-.1,1,1]
    θ = env.state.θ
    fillcolor := :red
    seriestype := :shape
    x*cos(θ) - y*sin(θ), y*cos(θ) + x*sin(θ)
  end

  # center
  @series begin
    seriestype := :scatter
    markersize := 10
    markercolor := :black
    annotations := [(0, -0.2, "a: $(round(env.a, digits = 4))", :top)]
    [0],[0]
  end
end

end
