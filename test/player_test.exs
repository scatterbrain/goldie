defmodule PlayerTest do
  use ExUnit.Case, async: false
  alias Goldie.Player
  import Mock
  doctest Goldie.Player

  setup do
    state = %Goldie.Player{
      components: [
        Goldie.Component.Mover
    ]}
    {:ok, state: state}
  end

  #test "init" do
    #  assert {:ok, _} = Player.init(:ref, :socket, :transport, [])
    #end

  test "handle_info setup", context do
    assert {:noreply, state} = Player.handle_info(:setup, context.state)
    assert state.entity.nearby == []
  end

  test "terminate", context do
    assert {:noreply, _state} = Player.terminate(:normal, context.state)
  end

  test "tcp" do
    transport = :ranch_tcp
    with_mock transport, [setopts: fn(_, _) -> :ok end] do
      data = %{}
      state = %Goldie.Player{
        socket: :socket, 
        transport: transport, 
        components: [
          Goldie.Component.SocketHandler
        ]}
      Player.handle_info({:tcp, :socket, data}, state)
      assert_receive {:event, {:socket_receive, data}, _}
    end
  end

  test "setup_components", context do
    assert {:ok, _} = Player.setup_components(context.state)
  end

  test "teardown_components", context do
    assert {:ok, _} = Player.teardown_components(context.state)
  end

  test "handle event" do
    state = %Goldie.Player{
      components: [
        Goldie.Component.Authentication
      ]}
    #Dummy message received by Authentication
    data = %{} 
    assert {:noreply, _} = Player.handle_info({:event, {:dummy, data}, self()}, state)
  end
end


