defmodule Goldie.Component.Mover do
  use Goldie.Component
  alias Goldie.Event
  require Logger

  @see_range 250.0 #0.6

  @spec setup(struct) :: {:ok, struct}  
  def setup(%{ :entity => entity } = state) do
    entity = Map.merge(entity, 
    %{
      nearby: [], 
      world_instance: "1"
    })
    {:ok,  %{ state | entity: entity }}
  end

  @spec teardown(struct) :: {:ok, struct}  
  def teardown(%{ :entity => entity } = state) do
    Goldie.LocGrid.remove_entity(entity)
    remove_self_nearby(entity)
    {:ok,  %{ state | entity: entity }}
  end

  @doc """
  Player spesific. Add player to world on register.
  """
  @spec handle_event(Event.t, pid, struct) :: {:ok|:stop, Event.t, struct}
  def handle_event({:register, _msg} = event, _from, %{ :entity => entity, :authenticated => true } = state) do
    send_player_spawn(entity, state, true)
    {:ok, event, %{ state | entity: entity }}
  end

  @doc """
  Player spesific. Add player to world on auth.
  """
  def handle_event({:auth, _msg} = event, _from, %{ :entity => entity, :authenticated => true } = state) do
    send_player_spawn(entity, state, true)
    {:ok, event, %{ state | entity: entity }}
  end

  @doc """
  Move message arrived from my client / NPC AI. Entity is starting to move. 
  """
  def handle_event({:move, msg} = event, _from, %{ :entity => entity} = state) do
    from_x = msg.fromX
    from_y = msg.fromY
    to_x = msg.toX
    to_y = msg.toY

    location = Goldie.Location.new(from_x, from_y, to_x, to_y)
    entity_with_new_loc = Map.put(entity, :loc, location)
    Goldie.LocGrid.move_entity(entity, entity_with_new_loc)
    entity = entity_with_new_loc
    #Calculate distances to entities on nearby list
    #TODO Interpolate other's correct position by interpolating between other.loc.from.x - other.loc.to.x
    nearby = for other <- entity.nearby, do: put_in(other, [:loc, :distance], Goldie.Location.xy_distance(other.loc.from.x, other.loc.from.y, from_x, from_y)) 
    {grid_nearby_entities, _distant_entities} = grid_nearby(entity, from_x, from_y)
    grid_nearby_entities
    |> Goldie.Utils.entity_union(nearby)
    |> notify_move(entity, true)
    {:ok, event, %{ state | entity: entity }}
  end

  @doc """
  Moved event arrived from another player or NPC. Someone has moved near me arriving to my see range, moving within it or leaving it.
  """
  def handle_event({:moved, msg} = _event, _from, %{ :entity => entity} = state) do
    moved_entity = msg.entity
    ## Other entity move may cause it to appear on our view, disappear from our view or move within our view
    {entity, move_type} = entity 
                          |> in_nearby(moved_entity) 
                          |> handle_moved(moved_entity, entity, msg.distance, msg.in_nearby)
     
    #Propagate the move_type to components coming after us
    msg = Map.put(msg, :move_type, move_type)
    event = {:moved, msg}
    {:ok, event, %{ state | entity: entity }}
  end
  
  @doc """
  Entity moved out of my area or died
  """
  def handle_event({removed_or_died, msg} = event, _from, %{ :entity => entity} = state) when removed_or_died == :removed or removed_or_died == :died do
    entity = do_nearby_delete(msg.entity, entity)
    #entity = do_remove_from_aggro(msg.entity, entity)
    {:ok, event, %{ state | entity: entity }}
  end

  @doc """ 
  This character moved to area with new entities. Those entities now introduce themselves
  """
  def handle_event({:intro, msg} = event, _from, %{ :entity => entity} = state) do
    intro_entity = msg.entity
    case Goldie.Utils.select_matches(entity.nearby, %{id: intro_entity.id}) do
      [] ->
        distance = case Map.get(msg, :distance, nil) do
          nil -> #All intro's don't necessarily include distance
            intro_from = intro_entity.loc.from 
            my_from = entity.loc.from
            Goldie.Location.xy_distance(my_from.x, my_from.y, intro_from.x, intro_from.y)
          dist ->
            dist
        end 
        entity = intro_entity 
                  |> Map.put(:distance, distance)
                  |> do_nearby_add(entity)
        #Propagate the move_type to components coming after us
        msg = Map.put(msg, :move_type, :appeared)
        event = {:intro, msg}
        {:ok, event, %{ state | entity: entity }}
      _ ->
        ## This can happen when player dies, removes itself from others on respawn 
        ## and they send re-intros to player
        {:stop, event, state}
    end 
  end

  @doc """
  Event Handler sink
  """
  def handle_event(event, _from, state) do
    {:ok, event, state}
  end

  ## handles moved message based on if the moved entity is already in entity's nearby list or not
  @spec handle_moved(nil | map, map, map, float, boolean) :: { map, :appeared | :moved | :disappeared }
  defp handle_moved(nil, moved_entity, entity, distance, _) do
    ## Entity moved to my area -> send introduction that I'm here and add to nearby
    intro = {:intro, %{ 
        id: entity.id, 
        entity: Goldie.Utils.entity_contact(entity),
        distance: distance
      }}
    Goldie.Event.send_event(moved_entity.pid, intro)
    moved_entity = Map.put(moved_entity, :distance, distance)
    #entity = update_area_aggro_list(entity, moved_entity)
    {do_nearby_add(moved_entity, entity), :appeared}
  end

  defp handle_moved(nearby_entity, moved_entity, entity, distance, in_nearby) do
    ## The entity either moved in my area or moved out from
    ## my area. 
    case distance <= @see_range do 
      true ->
        nearby_entity = Map.merge(nearby_entity, %{
          loc: moved_entity.loc, 
          distance: distance
        })
        nearby = [nearby_entity | Goldie.Utils.delete_matches(entity.nearby, %{id: moved_entity.id})]
        ## if I'm an NPC, I need to update my aggro list
        ## which contains every entity within my aggro
        ## distance                
        #entity = update_area_aggro_list(entity, nearby_entity)
        case in_nearby do
          nil ->
            ## Entity that I have in my nearby list moved but indicated that I'm not in
            ## in his nearby. This is an inconsistency that needs to be fixed. Send intro
            ## so that I'm added.
            intro = {:intro, %{ 
                id: entity.id, 
                entity: Goldie.Utils.entity_contact(entity),
                distance: distance
              }}
            Goldie.Event.send_event(moved_entity.pid, intro)
            :ok
          _ ->
            :ok
        end 
        {Map.put(entity, :nearby, nearby), :moved}
      false ->
        ## Entity moved out of my area -> send removed
        ## message that I'm not in range anymore. This
        ## will remove ME from HIM
        removed = {:removed, %{id: entity.id,
            entity: Goldie.Utils.entity_contact(entity)
          }}

        Goldie.Event.send_event(moved_entity.pid, removed)
        ## Remove HIM from ME
        {do_nearby_delete(moved_entity, entity), :disappeared}
    end
  end

  # finds the entities that are nearby according the grid
  @spec grid_nearby(struct, integer, integer) :: {map, map}
  defp grid_nearby(entity, x, y) do
    nearby_entities = Goldie.LocGrid.find_entities(x, y, entity.world_instance)
    #Remove self
    self_filtered = Goldie.Utils.delete_matches(nearby_entities, %{id: entity.id})
    nearby_entities_with_distance = for nearby <- self_filtered, do: put_in(nearby, [:loc, :distance], Goldie.Location.xy_distance(nearby.loc.from.x, nearby.loc.from.y, x, y)) 
    {within_see_range, within_grid} = within_range(nearby_entities_with_distance, @see_range)
    {within_see_range, within_grid}
  end

  ### Notify entities nearby that the notifier has moved in their area
  @spec notify_move(list, map, boolean) :: :ok
  defp notify_move(to_notify, notifier, move_start) do
    msg = %{
      id: notifier.id, 
      pid: notifier.pid, 
      entity: Goldie.Utils.entity_contact(notifier), 
      move_start: move_start
    }
  
    Enum.each(to_notify, 
      fn(entity_to_notify) ->
	      distance = entity_to_notify.loc.distance
              in_nearby = in_nearby(notifier, entity_to_notify) != nil
              msg = Map.merge(msg, %{
                distance: distance,
                in_nearby: in_nearby
              })
	      event = {:moved, msg}
	      Goldie.Event.send_event(entity_to_notify.pid, event)
      end)
    :ok
  end

  ## Remove self from all players nearby
  @spec remove_self_nearby(map) :: :ok
  defp remove_self_nearby(%{loc: _loc } = entity) do
    {grid_nearby_entities, _distant_entities} = grid_nearby(entity, entity.loc.from.x, entity.loc.from.y)
    Enum.each(grid_nearby_entities, 
      fn(nearby_entity) ->
          msg = %{id: entity.id, entity: Goldie.Utils.entity_contact(entity)}
          Goldie.Event.send_event(nearby_entity.pid, {<<"removed">>, msg})
      end)
  end
  defp remove_self_nearby(_entity) do
  end

  #Check if the given ToCheck entity is in Entity's nearby  
  @spec in_nearby(map, map) :: nil | map 
  defp in_nearby(entity, to_check) do
    case Goldie.Utils.select_matches(entity.nearby, %{id: to_check.id}) do
        [] ->
            nil 
        [nearby] ->
            nearby
    end
  end
  
  ## Return entities that are within range and outside of range
  @spec within_range(list, float) :: {list, list}
  defp within_range(entities, range) do
    Enum.partition(entities, 
    fn(entity) -> 
    entity.loc.distance <= range 
    end)
  end

  ##  removes character to the nearby list
  @spec do_nearby_delete(map, map) :: map
  defp do_nearby_delete(deleted_entity, entity) do 
    nearby = Goldie.Utils.delete_matches(entity.nearby, %{id: deleted_entity.id})
    #entity = update_area_aggro_list(entity, deleted_entity)
    Map.put(entity, :nearby, nearby)
  end

  ## adds a new character to the nearby list
  @spec do_nearby_add(map, map) :: map
  defp do_nearby_add(added_entity, entity) do
    entity = case in_nearby(entity, added_entity) do
      nil ->
            Map.put(entity, :nearby, [added_entity | entity.nearby])
      match ->
            exit({:exit, :do_nearby_add_already_exists, added_entity.id, match})
    end
    entity 
  end

  ## Send a spawn about the player to himself.
  defp send_player_spawn(entity, _state, initial_spawn) do
    goadd = Goldie.Message.goadd(entity.id, %{
        parent: "Camera Target",
        asset: "[Player]",
        components: %{
          :Scale => %{
            scale: [7.0, 7.0, 7.0]
          },
          :PlayerController => %{
            initialSpawn: initial_spawn 
          } 
         } 
      })

    Goldie.Component.SocketHandler.send_socket(goadd)
  end
end

