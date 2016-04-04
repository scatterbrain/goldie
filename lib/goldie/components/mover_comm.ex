defmodule Goldie.Component.MoverComm do
  use Goldie.Component
  require Logger
 
  @doc """
  Communicate to client information about movements in the player's view area. 
  This component is run after Mover component
  """
  def handle_event({:moved, msg} = event, _from, %{ :entity => entity} = state) do
    moved_entity = msg.entity
    move_type = msg.move_type
    initial_move = msg.move_start 

    entity = case move_type do
      :moved ->
        ## We only need the send the move message in case of the initial move. 
        ## After that the player is moving along its path and internal pos_update
        ## events don't need to update it.
        case initial_move do
          true ->
            send_move_msg(moved_entity, entity)
            entity
          _ ->
            entity
        end
      :appeared -> ## entity moved to our grid
        add_entity(moved_entity, entity)
      :disappeared ->
        remove_entity(moved_entity, entity)
    end

    {:ok, event, %{ state | entity: entity }}
  end

  def handle_event({:intro, msg} = event, _from, %{ :entity => entity} = state) do
    entity = add_entity(msg.entity, entity)
    {:ok, event, %{ state | entity: entity }}
  end

  def handle_event({:removed, msg} = event, _from, %{ :entity => entity} = state) do
    entity = remove_entity(msg.entity, entity)
    {:ok, event, %{ state | entity: entity }}
  end

  @doc """
  Event Handler sink
  """
  def handle_event(event, _from, state) do
    {:ok, event, state}
  end

  ## Add the entity to player by sending a GoAdd message to client
  @spec add_entity(map, map) :: map
  defp add_entity(added_entity, entity) do
    add_entity(added_entity, entity, false, nil, nil, false)
  end
  
  @spec add_entity(map, map, boolean, String.t, list, boolean) :: map
  defp add_entity(added_entity, entity, force_add, action_dependency, go_multi, initial_add) do
    ## each player process keeps track of which IDs have already been added,
    ## so that it won't add them more than once
    entity = case Enum.member?(Map.get(entity, :added_entity_ids, []), added_entity.id) do
      false ->
        added_entity_ids = Map.get(entity, :added_entity_ids, [])
        do_entity_add(added_entity, entity, action_dependency, go_multi, initial_add)
        Map.put(entity, :added_entity_ids, [added_entity.id | added_entity_ids])
      true when not force_add ->
        ## already added, don't add again
        entity
      true when force_add -> ## force add
        do_entity_add(added_entity, entity, action_dependency, go_multi, initial_add)
        entity
    end
    entity
  end

  ## Remove the entity to player by sending a GoRemove message to client
  @spec remove_entity(map, map) :: map
  defp remove_entity(removed_entity, entity) do
    Goldie.Component.SocketHandler.send_socket(Goldie.Message.goremove(removed_entity.id, %{}))
    added_entity_ids = Map.get(entity, :added_entity_ids, [])
    Map.put(entity, :added_entity_ids, List.delete(added_entity_ids, removed_entity.id)) 
  end

  @spec do_entity_add(map, map, map, String.t, boolean) :: map
  defp do_entity_add(added_entity, entity, action_dependency, go_multi, _initial_add) do
    #to_add = Map.take(added_entity, [:parent, :asset, :components, :alive])

    to_add = %{
        asset: "[#{added_entity.asset}]", 
        components: %{
          :Scale => %{
            scale: [7.0, 7.0, 7.0]
          },
          :Mover => %{
          } 
         } 
      }

    ##Entity may be in the process of moving a longer distance towards an end point
    ## if current marked locatipn is different from destination location it means that the
    ## entity is on the move.
    grid_loc = Map.get(added_entity, :loc, nil)
    case grid_loc do
      nil ->
        #In case the entity has removed it's location already
        :ok
      _ ->
        ## Send GoAdd
        #{x, y} = Goldie.Utils.loc_to_world(lat, lng)
        #to_add = tick_health(to_add)

        to_send = Goldie.Message.goadd(added_entity.id, to_add)
        ## add action dependency if needed
        to_send = case action_dependency do
          nil ->
            to_send
          _ ->
            Map.put(to_send, :actionDependency, action_dependency)
        end

        case action_dependency != nil and not Enum.member?(Map.get(entity, :added_entity_ids, []), action_dependency) do
          true ->
            ## If the client doesn't have the GameObject with id==EntityId, this GoAdd 
            ## will not work because the ActionDependency will trigger only when 
            ## GameObject that has id= ActionDependency is destroyed. 
            ## If the client doesn't have GameObject with id=EntityId then nothing 
            ## happens because there is no object to destroy. 
            Logger.error("***** #{inspect entity.id} do_entity_add for entity #{inspect added_entity.id} has action_dependency for #{added_entity.id} but #{inspect added_entity.id} is not present in added_entity_ids. THIS GOADD WILL NOT WORK ****")
            exit({:do_entity_add_action_dependency, action_dependency, Map.get(entity, :added_entity_ids, [])})
          _ ->
            :ok
        end

        ## send gomulti if needed, otherwise just the regular goadd
        to_send = case go_multi do
          nil ->
            to_send
          _ ->
            objects = [to_send | go_multi]
            Goldie.Message.gomulti(objects)
        end
        Goldie.Component.SocketHandler.send_socket(to_send)

        ## Finally check if the entity is currently on the move
        remaining_dist = Goldie.Location.xy_distance(grid_loc.from.x, grid_loc.from.y, grid_loc.to.x, grid_loc.to.y)

        ## Check if the entity has reached the end position with a magic threshold
        case remaining_dist > 0.0 do
          true ->
            ##If the entity is on the move, send a additional move message to put the entity on the move in the client
            send_move_msg(added_entity, entity)
          _ ->
            :ok
        end
    end
  end

  ## send a move gomodify message to client 
  @spec send_move_msg(map, map) :: :ok
  defp send_move_msg(moving_entity, _entity) do 
    location_age = Goldie.Utils.timestamp_ms() - moving_entity.loc.updated
    gomodify = Goldie.Message.gomodify(moving_entity.id,
    %{
      components: %{
        :Mover => %{
          from: [moving_entity.loc.from.x, moving_entity.loc.from.y],
          to: [moving_entity.loc.to.x, moving_entity.loc.to.y],
          age: location_age 
        } 
      } 
    })
    Goldie.Component.SocketHandler.send_socket(gomodify)
    :ok
  end
end
