defmodule Goldie.Component.Spawner do
  use Goldie.Component
  require Logger

  @spawn_interval 30_000
  @spawn_distance 250

  @spec setup(struct) :: {:ok, struct}  
  def setup(%{ :entity => entity } = state) do
    {:ok,  %{ state | entity: entity }}
  end

  @spec teardown(struct) :: {:ok, struct}  
  def teardown(%{ :entity => entity } = state) do
    entity = Map.delete(entity, :last_spawn)
    {:ok,  %{ state | entity: entity }}
  end
  
  @doc """
  Spawn NPCs on movement 
  """
  def handle_event({:move, _msg} = event, _from, %{ :entity => entity } = state) do
    last_spawn = Map.get(entity, :last_spawn, nil)
    entity = handle_spawn(last_spawn, entity)
    {:ok, event, %{ state | entity: entity }}
  end

  @doc """
  Event Handler sink
  """
  def handle_event(event, _from, state) do
    {:ok, event, state}
  end

  ## No record of last spawn
  @spec handle_spawn(map, map) :: map
  defp handle_spawn(nil, entity) do
    handle_spawn(entity)
  end

  ## Spawn a NPC if
  ## there has been spawn_interval since last spawn or
  ## there is sufficient distance since last spawn
  defp handle_spawn(last_spawn, entity) do 
    case Goldie.Utils.ms_since_timestamp_ms(last_spawn.timestamp) > @spawn_interval 
    or Goldie.Location.xy_distance(
        entity.loc.from.x, entity.loc.from.y, 
        last_spawn.loc.x, last_spawn.loc.y
        ) > @spawn_distance do
      true ->
        handle_spawn(entity)
      _ ->
        entity
    end
  end
  
  @spec handle_spawn(map) :: map
  defp handle_spawn(entity) do
    Goldie.NPC.spawn(entity.loc.from)
    last_spawn = %{ timestamp: Goldie.Utils.timestamp_ms(), 
      loc: %{x: entity.loc.from.x, y: entity.loc.from.y }}
    Map.put(entity, :last_spawn, last_spawn)
  end
end
