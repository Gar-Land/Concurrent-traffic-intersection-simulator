run_full_simulation = fn ->
  {:ok, path} = File.cwd()
  Code.require_file(Path.join(path, "lib/proyecto-0.exs"))
end

{time, _result} = :timer.tc(run_full_simulation)
IO.puts("Tiempo de ejecución: #{time} ms")
