defmodule Goldie.LocGrid do
  use GenServer
  require Logger

  @max_lat_cells 20000
  @max_lng_cells 20000

  defstruct [:entities, :reverse]

  def start_link(_opts = []) do
    GenServer.start_link(__MODULE__, :ok, [name: {:global, __MODULE__}])
  end

  @doc """
  Finds entities of a certain type around given Lat/Lng. 
  """
  @spec find_entities(float, float, String.t) :: list
  def find_entities(lat, lng, world_instance) do
    {qla, qlo} = quantize_lat_long(lat, lng)
    ids = for lat_gq <- [qla - 1, qla, qla + 1], lng_gq <- [qlo - 1, qlo, qlo + 1], do: grid_id(lat_gq, lng_gq, world_instance) 
    GenServer.call({:global, __MODULE__}, {:find_entities, ids}, :infinity)
  end

  @doc """
  Adds an entity to the right grid location based on lat/lng
  """
  @spec add_entity(map) :: :ok
  def add_entity(entity) do
    GenServer.call({:global, __MODULE__}, {:add_entity, entity_grid_id(entity), Goldie.Utils.entity_contact(entity)})
  end

  @doc """
  Removes an entity contact from grid location based on lat/lng 
  """
  @spec remove_entity(map) :: :ok
  def remove_entity(%{loc: _loc } = entity) do
    GenServer.cast({:global, __MODULE__}, {:remove_entity, entity_grid_id(entity), Goldie.Utils.entity_contact(entity)})
  end

  def remove_entity(_entity) do
    #Entity has no location yet (first move_entity call when player has no old loc yet)
  end

  @doc """
  Move an entity from one grid location to another
  """
  @spec move_entity(map, map) :: :ok
  def move_entity(old_entity, new_entity) do
    remove_entity(old_entity) 
    add_entity(new_entity)
  end

  @doc """
  Clears the data
  """
  @spec clear() :: :ok
  def clear() do
    GenServer.call({:global, __MODULE__}, {:clear})
  end

  @doc """
  Create a grid id for an entity
  """
  @spec entity_grid_id(map) :: String.t 
  def entity_grid_id(entity) do
    loc = entity.loc
    {qla, qlo} = quantize_lat_long(loc.from.x, loc.from.y)
    grid_id(qla, qlo, entity.world_instance)
  end

  @doc """
  Grid ids are based on map grids
  """
  @spec grid_id(integer, integer, String.t) :: String.t
  def grid_id(lat_q, lng_q, world_instance) do
    "#{lat_q}-#{lng_q}-#{world_instance}"
  end

  ## GenServer callbacks

  def init(_opts) do
    Logger.debug("LocGrid starting")
    entities = :ets.new(:entities_grid, [:bag, :named_table])
    reverse = :ets.new(:name_grid, [:bag, :named_table])
    {:ok, %Goldie.LocGrid { entities: entities, reverse: reverse }}
  end

  def handle_call({:find_entities, ids}, _from, state) do
    entity_contacts = Enum.reduce(ids, [], fn(grid_id, acc_in) ->
      entities = for {_, x} <- :ets.lookup(state.entities, grid_id), do: x
      acc_in ++ entities
    end)

    {:reply, entity_contacts, state}
  end

  def handle_call({:add_entity, grid_id, entity}, _from, state) do
    table = state.entities
    reverse = state.reverse
    grid_cell = for {_grid_id, value} <- :ets.lookup(table, grid_id), do: value
    matches = Goldie.Utils.select_matches(grid_cell, %{id: entity.id}) 

    case matches do
        [] ->
            :ets.insert(table, {grid_id, entity}) 
            :ets.insert(reverse, {entity.id, grid_id})
        _ ->
            do_remove(entity, state)
            exit({:error, :entity_already_exists})
    end
    
    {:reply, :ok, state}
  end

  def handle_call({:clear}, _from, state) do
    table = state.entities    
    :ets.delete_all_objects(table)
    {:reply, :ok, state}
  end

  def handle_cast({:remove_entity, _grid_id, entity}, state) do
    do_remove(entity, state)
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.debug("LogGrid terminate #{reason}")
    :ets.delete(state.entities)
    :ets.delete(state.reverse)
    :ok
  end

  ## Remove the entity from the grid based on its id->gridid reverse lookup table
  def do_remove(entity, state) do
    table = state.entities
    #Look from the reverse lookup table where the Entity is
    reverse = state.reverse
    id = entity.id
    grid_cells = for {_entity_id, grid_id} <- :ets.lookup(reverse, id), do: grid_id 

    case length(grid_cells) > 1 do
      true ->
        exit({"LocGrid.do_remove reverse grid find finds multiple grid ids", grid_cells, id})
      _ ->
        :ok
    end 

    #Remove from the actual grid table
    Enum.each(grid_cells, fn(grid_id) ->
      grid_cell = for {_grid_id, value} <- :ets.lookup(table, grid_id), do: value

      #Can't delete_object Entity because it may have different field values
      #than the object in the ets table. We only care that the ids are the same.
      #That's why we have to find the object that is in ets (del_entity)
      matches = Goldie.Utils.select_matches(grid_cell, %{ id: entity.id })
      Enum.each(matches, fn(del_entity) ->
        :ets.delete_object(table, {grid_id, del_entity})
      end)
    end)

    ## Clear the reverse lookup for this entity
    :ets.delete(reverse, id)
    :ok
  end

  ## quantize lat and lng coordinates into grid cells
  @spec quantize_lat_long(float, float) :: {integer, integer}
  defp quantize_lat_long(lat, lng) do
    #lat_q = 1 + Float.floor(((lat + 90.0) / 180.0) * (@max_lat_cells - 1))
    #lng_q = 1 + Float.floor(((lng + 180.0) / 360.0) * (@max_lng_cells - 1))
    #{lat_q, lng_q}
    #Everyone goes to same grid cell atm
    {1, 1}
  end
end
