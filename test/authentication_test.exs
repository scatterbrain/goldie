defmodule AutenticationTest do
  use ExUnit.Case, async: false
  alias Goldie.Component.Authentication
  doctest Goldie.Component.Authentication

  setup do
    assert {:ok, state} = Authentication.setup(%Goldie.Player{})
    on_exit fn ->
      assert {:ok, _state} = Authentication.teardown(state)    
    end

    {:ok, state: state}
  end

  test "event register", context do
    state = context.state
    assert {:ok, {:register, _}, state} = Authentication.handle_event({:register, %{passwd_hash: "123456"}}, self(), state)
    assert state.authenticated == true
  end

  test "event login", context do
    state = context.state
    assert {:ok, {:auth, _}, state} = Authentication.handle_event({:auth, %{id: "player123", passwd_hash: "123456"}}, self(), state)
    assert state.authenticated == true
  end


end


