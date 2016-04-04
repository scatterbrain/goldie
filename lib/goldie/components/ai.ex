defmodule Goldie.Component.AI do
  use Goldie.Component
  require Logger

  @move_interval 15_000
  @move_distance 250
  
  @doc """
  Start new timer for the next move 
  """
  def handle_event({:move, _msg} = event, _from, state) do
    {:ok, tref} = Goldie.Event.send_after({:new_move, %{}}, @move_interval)
    timers = Map.put(state.timers, :new_move, tref)
    state = Map.put(state, :timers, timers)
    {:ok, event, state}
  end

  @doc """
  Receive an instruction to do a new move 
  """
  def handle_event({:new_move, _msg} = event, _from, %{ :entity => entity } = state) do
    #Make sure location is up to date
    loc = Goldie.Location.interpolate(entity.loc, 10.0)
    entity = Map.put(entity, :loc, loc)

    #distance between -move_distance and move_distance
    distance_x = :random.uniform(@move_distance*2) - @move_distance
    distance_y = :random.uniform(@move_distance*2) - @move_distance
    msg = %{
      fromX: entity.loc.from.x,
      fromY: entity.loc.from.y,
      toX: entity.loc.to.x + distance_x,
      toY: entity.loc.to.y + distance_y
    }
    Goldie.Event.send_event({:move, msg})
    {:ok, event, %{ state | entity: entity }}
  end

  @doc """
  Event Handler sink
  """
  def handle_event(event, _from, state) do
    {:ok, event, state}
  end
end
