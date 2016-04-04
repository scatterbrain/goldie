defmodule Goldie.NPC do
  @moduledoc """
  NPC process 
  """
  use Goldie.ComponentServer.GenServer
  require Logger

  @components [
    Goldie.Component.Mover, 
    Goldie.Component.AI
  ]

  defstruct components: [],
  timers: %{},
  entity: %{}

  def spawn(loc) do 
    Goldie.SupervisorNPC.start_npc([loc])
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(loc) do
    state = %Goldie.NPC{
      components: @components,
      entity: %{
        id: Goldie.Utils.id(:npc), 
        pid: self(), 
        asset: "GhostEnemyOrange"
      }
    }
    send self(), {:setup, loc}
    {:ok, state}
  end

  def handle_info({:setup, loc}, state) do
    {:ok, state} = setup_components(state)
    entity = state.entity
    #Initial move to add to world
    entity = Map.put(entity, :loc, Goldie.Location.new(loc.x, loc.y, loc.x, loc.y))
    Goldie.Event.send_event({:new_move, %{}})
    {:noreply, %{ state | entity: entity }}    
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    Logger.debug("NPC terminate")
    {:ok, state} = teardown_components(state)
    {:noreply, state}
  end
end
