defmodule Goldie.Location do
  @moduledoc """
  Entity location in the world
  """
  require Logger

  #defstruct [:from, :to, :ppos, :updated]
  
  @spec xy_distance(number, number, number, number) :: map   
  def new(from_x, from_y, to_x, to_y) do
    %{ 
      from: %{ x: from_x, y: from_y }, 
      to: %{ x: to_x, y: to_y },
      ppos: 0.0, ## Current progress on the path
      updated: Goldie.Utils.timestamp_ms() ##When was the position updated (now)
    }
  end

  @spec interpolate(map, number) :: map
  def interpolate(loc, velocity) do
    now = Goldie.Utils.timestamp_ms()
    time_passed = now - loc.updated 
    distance = xy_distance(loc.from.x, loc.from.y, loc.to.x, loc.to.y)
    {x, y} = do_interpolate(loc, velocity, distance, time_passed)
    from = %{ loc.from | x: x, y: y}
    %{loc | from: from, updated: now }
  end

  @doc """
  Distance between to points
  """
  @spec xy_distance(number, number, number, number) :: number 
  def xy_distance(from_x, from_y, to_x, to_y) do
    :math.sqrt(:math.pow(to_x - from_x, 2) + :math.pow(to_y - from_y, 2))
  end

  @spec do_interpolate(map, number, number, number) :: {number, number}
  defp do_interpolate(loc, _velocity, 0.0, _time_passed), do: {loc.from.x, loc.from.y}
  defp do_interpolate(loc, velocity, distance, time_passed) do
    step = (time_passed / 1000.0) * velocity #Velocity is given as units / second
    t = Goldie.Utils.min(1.0, step / distance)
    Graphmath.Vec2.lerp({loc.from.x, loc.from.y}, {loc.to.x, loc.to.y}, t)
  end
end
