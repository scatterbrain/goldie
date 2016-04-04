defmodule MoverTest do
  use ExUnit.Case, async: false
  require Logger
  alias Goldie.Component.Mover
  doctest Goldie.Component.Mover

  setup do
    assert {:ok, state} = Mover.setup(%{ entity: %{id: "myid", pid: self()}})
    my_location = %{ 
      from: %{ x: 0.0, y: 0.0 }, 
      to: %{ x: 0.001, y: 0.001 },
      ppos: 0.0, 
      updated: Goldie.Utils.timestamp_ms()
    }
    state = put_in(state, [:entity, :loc], my_location)
    state = Map.put(state, :authenticated, true)
    on_exit fn ->
      assert {:ok, _state} = Mover.teardown(state)
      Goldie.LocGrid.clear() 
    end

    {:ok, state: state}
  end

  test "event register", context do
    state = context.state
    assert {:ok, {:register, _}, _state} = Mover.handle_event({:register, %{}}, self(), state)
  end

  test "event login", context do
    state = context.state
    assert {:ok, {:auth, _}, _state} = Mover.handle_event({:auth, %{}}, self(), state)
  end

  test "move and inform nearby", context do
    state = context.state
    nearby_location = %{ 
      from: %{ x: 0.0, y: 0.0 }, 
      to: %{ x: 0.001, y: 0.001 },
      ppos: 0.0, ## Current progress on the path
      updated: Goldie.Utils.timestamp_ms() ##When was the position updated (now)
    }
    state = put_in(state, [:entity, :nearby], [%{id: "otherid", pid: self(), loc: nearby_location}])
    msg = %{
      fromX: 0.0, 
      fromY: 0.0, 
      toX: 0.0001, 
      toY: 0.0001
    } 
    assert {:ok, {:move, _}, _state} = Mover.handle_event({:move, msg}, self(), state)
    assert_receive {:event, {:moved, _}, _}
  end

  test "move and inform grid", context do
    state = context.state
    nearby_location = %{ 
      from: %{ x: 0.0, y: 0.0 }, 
      to: %{ x: 0.001, y: 0.001 },
      ppos: 0.0, ## Current progress on the path
      updated: Goldie.Utils.timestamp_ms() ##When was the position updated (now)
    }

    grid_entity = %{id: "otherid", pid: self(), loc: nearby_location, world_instance: "1"}
    Goldie.LocGrid.add_entity(grid_entity)

    #Nearby is empty
    state = put_in(state, [:entity, :nearby], [])
    my_location = %{ 
      from: %{ x: 0.0, y: 0.0 }, 
      to: %{ x: 0.001, y: 0.001 },
      ppos: 0.0, 
      updated: Goldie.Utils.timestamp_ms()
    }
    state = put_in(state, [:entity, :loc], my_location)

    msg = %{
      fromX: 0.0, 
      fromY: 0.0, 
      toX: 0.0001, 
      toY: 0.0001
    } 
    assert {:ok, {:move, _}, _state} = Mover.handle_event({:move, msg}, self(), state)
    assert_receive {:event, {:moved, _}, _}
  end

  test "someone moved in my nearby list", context do
    state = context.state
    other_location = %{ 
      from: %{ x: 0.0001, y: 0.0001 }, 
      to: %{ x: 0.0002, y: 0.0002 },
      ppos: 0.0, ## Current progress on the path
      updated: Goldie.Utils.timestamp_ms() ##When was the position updated (now)
    }
    other_entity = %{id: "otherid", pid: self(), loc: other_location}
    state = put_in(state, [:entity, :nearby], [other_entity])
    my_location = %{ 
      from: %{ x: 0.0, y: 0.0 }, 
      to: %{ x: 0.001, y: 0.001 },
      ppos: 0.0, 
      updated: Goldie.Utils.timestamp_ms()
    }
    state = put_in(state, [:entity, :loc], my_location)
    msg = %{
      entity: other_entity, 
      in_nearby: true, 
      distance: 0.0
    } 
    assert {:ok, {:moved, msg}, state} = Mover.handle_event({:moved, msg}, self(), state)
    [moved_entity] = Goldie.Utils.select_matches(state.entity.nearby, %{id: "otherid"})
    assert msg.move_type == :moved
    assert moved_entity.loc.from.x == 0.0001
  end

  test "someone moved to my area", context do
    state = context.state
    other_location = %{ 
      from: %{ x: 0.0001, y: 0.0001 }, 
      to: %{ x: 0.0002, y: 0.0002 },
      ppos: 0.0, ## Current progress on the path
      updated: Goldie.Utils.timestamp_ms() ##When was the position updated (now)
    }
    other_entity = %{id: "otherid", pid: self(), loc: other_location}
    #Nearby is empty
    state = put_in(state, [:entity, :nearby], [])
    my_location = %{ 
      from: %{ x: 0.0, y: 0.0 }, 
      to: %{ x: 0.001, y: 0.001 },
      ppos: 0.0, 
      updated: Goldie.Utils.timestamp_ms()
    }
    state = put_in(state, [:entity, :loc], my_location)
    msg = %{
      entity: other_entity, 
      in_nearby: true, 
      distance: 0.0
    } 
    assert {:ok, {:moved, msg}, state} = Mover.handle_event({:moved, msg}, self(), state)
    [moved_entity] = Goldie.Utils.select_matches(state.entity.nearby, %{id: "otherid"})
    assert msg.move_type == :appeared
    assert moved_entity.loc.from.x == 0.0001
    assert_receive {:event, {:intro, _}, _}    
  end

  test "someone left my area", context do
    state = context.state
    other_location = %{ 
      from: %{ x: 0.0001, y: 0.0001 }, 
      to: %{ x: 0.0002, y: 0.0002 },
      ppos: 0.0, ## Current progress on the path
      updated: Goldie.Utils.timestamp_ms() ##When was the position updated (now)
    }
    other_entity = %{id: "otherid", pid: self(), loc: other_location}
    state = put_in(state, [:entity, :nearby], [other_entity])
    my_location = %{ 
      from: %{ x: 0.0, y: 0.0 }, 
      to: %{ x: 0.001, y: 0.001 },
      ppos: 0.0, 
      updated: Goldie.Utils.timestamp_ms()
    }
    state = put_in(state, [:entity, :loc], my_location)
    
    other_location_after_move = %{ 
      from: %{ x: 100.1, y: 100.1 }, 
      to: %{ x: 100.2, y: 100.2 },
      ppos: 0.0, ## Current progress on the path
      updated: Goldie.Utils.timestamp_ms() ##When was the position updated (now)
    }
    other_entity_after_move = %{other_entity | loc: other_location_after_move}
    msg = %{
      entity: other_entity_after_move, 
      in_nearby: true, 
      distance: 1000.0
    } 
    assert {:ok, {:moved, msg}, state} = Mover.handle_event({:moved, msg}, self(), state)
    [] = Goldie.Utils.select_matches(state.entity.nearby, %{id: "otherid"})
    assert msg.move_type == :disappeared
    assert_receive {:event, {:removed, _}, _}        
  end
  
  test "someone introed", context do
    state = context.state
    other_location = %{ 
      from: %{ x: 0.0001, y: 0.0001 }, 
      to: %{ x: 0.0002, y: 0.0002 },
      ppos: 0.0, ## Current progress on the path
      updated: Goldie.Utils.timestamp_ms() ##When was the position updated (now)
    }
    other_entity = %{id: "otherid", pid: self(), loc: other_location}
    #Nearby is empty
    state = put_in(state, [:entity, :nearby], [])
    my_location = %{ 
      from: %{ x: 0.0, y: 0.0 }, 
      to: %{ x: 0.001, y: 0.001 },
      ppos: 0.0, 
      updated: Goldie.Utils.timestamp_ms()
    }
    state = put_in(state, [:entity, :loc], my_location)
    msg = %{
      entity: other_entity, 
      distance: 0.0
    } 
    assert {:ok, {:intro, msg}, state} = Mover.handle_event({:intro, msg}, self(), state)
    [_introed_entity] = Goldie.Utils.select_matches(state.entity.nearby, %{id: "otherid"})
    assert msg.move_type == :appeared
  end

  test "someone introed without distance", context do
    state = context.state
    other_location = %{ 
      from: %{ x: 0.0001, y: 0.0001 }, 
      to: %{ x: 0.0002, y: 0.0002 },
      ppos: 0.0, ## Current progress on the path
      updated: Goldie.Utils.timestamp_ms() ##When was the position updated (now)
    }
    other_entity = %{id: "otherid", pid: self(), loc: other_location}
    #Nearby is empty
    state = put_in(state, [:entity, :nearby], [])
    my_location = %{ 
      from: %{ x: 0.0, y: 0.0 }, 
      to: %{ x: 0.001, y: 0.001 },
      ppos: 0.0, 
      updated: Goldie.Utils.timestamp_ms()
    }
    state = put_in(state, [:entity, :loc], my_location)
    msg = %{
      entity: other_entity
    } 
    assert {:ok, {:intro, msg}, state} = Mover.handle_event({:intro, msg}, self(), state)
    [_introed_entity] = Goldie.Utils.select_matches(state.entity.nearby, %{id: "otherid"})
    assert msg.move_type == :appeared
  end

  test "someone introed when already on my nearby", context do
    state = context.state
    other_location = %{ 
      from: %{ x: 0.0001, y: 0.0001 }, 
      to: %{ x: 0.0002, y: 0.0002 },
      ppos: 0.0, ## Current progress on the path
      updated: Goldie.Utils.timestamp_ms() ##When was the position updated (now)
    }
    other_entity = %{id: "otherid", pid: self(), loc: other_location}
    state = put_in(state, [:entity, :nearby], [other_entity])
    my_location = %{ 
      from: %{ x: 0.0, y: 0.0 }, 
      to: %{ x: 0.001, y: 0.001 },
      ppos: 0.0, 
      updated: Goldie.Utils.timestamp_ms()
    }
    state = put_in(state, [:entity, :loc], my_location)
    msg = %{
      entity: other_entity, 
      distance: 0.0
    } 
    assert {:stop, {:intro, _msg}, _state} = Mover.handle_event({:intro, msg}, self(), state)
  end

  test "someone removed or died", context do
    state = context.state
    other_location = %{ 
      from: %{ x: 0.0001, y: 0.0001 }, 
      to: %{ x: 0.0002, y: 0.0002 },
      ppos: 0.0, ## Current progress on the path
      updated: Goldie.Utils.timestamp_ms() ##When was the position updated (now)
    }
    other_entity = %{id: "otherid", pid: self(), loc: other_location}
    #Nearby is empty
    state = put_in(state, [:entity, :nearby], [])
    my_location = %{ 
      from: %{ x: 0.0, y: 0.0 }, 
      to: %{ x: 0.001, y: 0.001 },
      ppos: 0.0, 
      updated: Goldie.Utils.timestamp_ms()
    }
    state = put_in(state, [:entity, :loc], my_location)
    msg = %{
      entity: other_entity, 
      distance: 0.0
    } 
    assert {:ok, {:removed, msg}, state} = Mover.handle_event({:removed, msg}, self(), state)
    [] = Goldie.Utils.select_matches(state.entity.nearby, %{id: "otherid"})
    assert {:ok, {:died, _msg}, state} = Mover.handle_event({:died, msg}, self(), state)
    [] = Goldie.Utils.select_matches(state.entity.nearby, %{id: "otherid"})
  end

end


