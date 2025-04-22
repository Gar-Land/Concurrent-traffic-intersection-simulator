defmodule Simulador do
  # función que se encarga de escribir las estadísticas individuales de alguna calle
  def write_stats(sof, crossings, percentiles) do
    IO.puts("ESCRIBIENDO TODOS LOS CÁLCULOS\n")

    # almacenaremos todo el contenido en memoria através
    # de una lista llamada o_strings
    o_strings = [
      "Los cruceros simulados son: " <> Enum.join(Map.keys(crossings), " "),
      "\n\r"
    ]

    # se usa concurrencia sobre un mapa de mapas y tal que para
    # cada para cada mapa contenido dentro del mapa se invoca
    # un proceso de Elixir/Erlang que almacena dentro de una lista
    # el contenido que será escrito acerca de un cruce en particular
    c_strings =
    Task.async_stream(crossings, fn {key, stats} ->
      [
        "Crucero #{key}\nDe clase #{stats[:class]}\n",
        Enum.join(stats[:st_1][:times], "s, ") <> "s\n",
        "Número de vehículos sobre la calle: #{stats[:st_1][:cars]}\n",
        "Tiempo promedio en cruzar la calle: #{stats[:st_1][:avg]}s\n\n",
        Enum.join(stats[:st_2][:times], "s, ") <> "s\n",
        "Número de vehículos sobre la calle: #{stats[:st_2][:cars]}\n",
        "Tiempo promedio en cruzar la calle: #{stats[:st_2][:avg]}s\n\n",
        "Número de vehículos en #{key}: #{stats[:cars]}\n",
        "Tiempo promedio en cruzar #{key}: #{stats[:avg]}s\n\n"
      ]
    end, ordered: false) |> Enum.map(fn {:ok, result} -> result end)

    # aplanamos la lista de listas (c_strings) y
    # la adjuntamos a o_strings
    o_strings = o_strings ++ List.flatten(c_strings)

    # luego añadimos las estadísticas generales de los cruceros
    # a la lista que almacenará todo el contenido
    o_strings = o_strings ++ [
      "Estadisticas generales de los cruceros\n\n",
      "Cruceros en el 1er percentil de mayor tiempo promedio de espera: " <>
      Enum.join(
        Enum.filter(crossings, fn {_, stats} -> stats[:avg] == percentiles[10] end)
        |> Enum.map(fn {key, _} -> key end),
        " "
      ),
      "\n",
      "Cruceros en el 9no percentil de mayor tiempo promedio de espera: " <>
      Enum.join(
        Enum.filter(crossings, fn {_, stats} -> stats[:avg] == percentiles[90] end)
        |> Enum.map(fn {key, _} -> key end),
        " "
      ),
      "\n"
    ]

    # abrimos el archivo de salida y unimos o_strings en una sola string,
    # evitamos acceder y escribir multiples veces al archivo. Algo que
    # causaría sobrecarga al programa
    {:ok, file} = File.open(sof, [:write])
    IO.binwrite(file, Enum.join(o_strings, ""))
    File.close(file)
  end

  # función que usando concurrencia calcula los tiempos de espera
  # para un número de vehículos
  def trigger(cars, tl, ft) do
    cycle = tl["g"] + tl["y"] + tl["r"]  # se inicializa variable por motivos de legibilidad y eficiencia
    window = tl["g"] + tl["y"]           # se inicializa variable por motivos de legibilidad y eficiencia
    red = tl["r"]                        # se inicializa variable por motivos de legibilidad y eficiencia

    Enum.map(cars, fn car ->
      rem = rem(car, cycle)              # se inicializa variable por motivos de legibilidad y eficiencia
      cond do
        0 <= car && car <= window ->  # pasa en seguida porque su tiempo de llegada es menor a la suma de
        # los estados verde y amarillo
          car + ft
        window < car && car <= cycle -> # cuando llega despues de la suma de los estados verde y amarillo
        # y pasará en cycle mod car segundos
          rem(cycle, car) + ft
        cycle < car && rem <= window -> # cuando llega después del primer ciclo, y car mod cycle es menor
        # o igual que la suma los estados verde y amarillo. Pasará después de car div cycle ciclos
          rem + ft
        cycle < car && rem > window ->  # cuando llega después del primer ciclo, y car mod cycle es mayor
        # que la suma los estados verde y amarillo. Pasará después de ciertos segundos porque llegó cuando
        # el semáforo estaba en rojo
          red - (rem - window) + ft
      end
    end)
  end

  def stats(street) do
    calced_t = Enum.map(street, fn {_key, tl} ->
      tl["cars"] |> trigger(tl["config"], tl["ft"])
    end) |> List.flatten()

    cars = length(calced_t) # calcula el número de vehículos sobre alguna calle
    avg_t = Enum.sum(calced_t) / cars # calcula el promedio de tiempo de alguna calle

    %{times: calced_t, cars: cars, avg: avg_t} # se retorna un mapa con los calculos anteriores
  end

  # función que se encarga de calcular las estadisticas tanto individuales como
  # generales de los cruceros, además invoca a la función write_stats
  def calc_stats(sof, crossings) do
    # parte concurrente del código que genera procesos de Elixir/Erlang por cada
    # crucero, tal que cada proceso de Elixir/Erlang está encargado de cacular las
    # estadisticas de un crucero en particular.
    crossing_stats =
    Task.async_stream(crossings, fn {key, crossing} ->
      IO.puts("CALCULANDO LAS ESTADÍSTICAS DEL CRUCERO: #{String.upcase(key)}")
      {st1, st2} = {crossing["st_1"], crossing["st_2"]}

      IO.puts("CALCULANDO TIEMPOS DE ESPERA ASOCIADOS A LA 1RA CALLE DE #{String.upcase(key)}")
      st1 = stats(st1)
      IO.puts("CALCULANDO TIEMPOS DE ESPERA ASOCIADOS A LA 2DA CALLE DE #{String.upcase(key)}")
      st2 = stats(st2)

      IO.puts("CALCULANDO ESTADÍSTICAS INDIVIDUALES DE #{String.upcase(key)}")
      calced_t = st1[:times] ++ st2[:times]
      cars = length(calced_t)
      avg = Enum.sum([st1[:avg] + st2[:avg]]) / 2

      {key, %{class: crossing["class"], cars: cars, avg: avg, st_1: st1,st_2: st2}}
    end, ordered: false) |> Enum.map(fn {:ok, result} -> result end) |> Enum.into(%{})

    # se calculan los percentiles con Statistex (módulo de Elixir)
    IO.puts("CALCULANDO PERCENTILES DE LAS ESTADÍSTICAS GENERALES DE LOS CRUCEROS")
    percentiles = crossing_stats
    |> Enum.map(fn {_, stats} -> stats[:avg] end)
    |> Statistex.percentiles([10, 90])

    write_stats(sof, crossing_stats, percentiles) # se pasan como argumento tanto
    # el mapa actualizado como los percentiles
  end

  # función que se encarga de extraer desde un json alguna estructura de datos
  # (el conjunto de cruceros y el conjunto de listas de tiempos de llegada)
  def fromJSON(path) do
    case File.read(path) do
      {:ok, json} -> # en dado caso de que sí exista devuelve el contenido del json
        case Jason.decode(json) do # parsea el contenido del json a mapas anidados
        # (modela el conjunto de cruceros) con Jason (módulo de Elixir)
          {:ok, data} -> data # extrae la estructura de datos
          # (mapa de mapas) que contiene la información de los cruceros
          {:error, reason} -> raise("Error al decodificar json: #{reason}")
        end
      {:error, :enoent} -> # arroja una excepción en caso de no encontrar o que no exista el archivo
        raise("Error: Ningún archivo o directorio fue encontrado en #{path}")
    end
  end
end

IO.puts("SIMULADOR DE CRUCEROS (CON CONCURRENCIA)\n")
{ds_f, c_f, cof} = {"data-structures.json", "cars.json", "calculated-times-1.txt"}
# ajustamos el directorio actual
File.cd("./tests/test_data")
{:ok, path} = File.cwd() # Se extrea la representacíon
# string del directorio actual que es almacenada en path

# se manda a llamar la función que obtiene a las estructura de datos
IO.puts("INICIO DE EXTRACCIÓN DE LAS ESTRUCTURAS DE DATOS DE: #{String.upcase(ds_f)}")
crossings = Simulador.fromJSON(Path.join(path , ds_f))
IO.puts("INICIO DE EXTRACCIÓN DE LAS ESTRUCTURAS DE DATOS DE: #{String.upcase(c_f)}")
cars = Simulador.fromJSON(Path.join(path, c_f))

# se actualiza el mapa con las listas de tiempos de llegada
# asociada con un semáforo en particular de una calle en particular
# de un crucero en particular
crossings = Enum.reduce(cars["cars"], crossings, fn car, updated_crossings ->
  {c, st, tl}= {car["c"], car["st"], car["tl"]}
  put_in(updated_crossings[c][st][tl]["cars"], car["arrivingTimes"])
end)

run_full_simulation = fn ->
  IO.puts("INICIO DEL CÁLCULO DE ESTADÍSTICAS\n")
  # se manda a llamar la función que inicia a la simulación
  Simulador.calc_stats(Path.join(path, cof), crossings)
  IO.puts("ARCHIVO TXT DE SALIDA YA ESTÁ DISPONIBLE")
  IO.puts("SIMULADOR DEL CRUCERO FINALIZADO")
end

{time, _result} = :timer.tc(run_full_simulation)
IO.puts("Tiempo de ejecución: #{time / 1000000} segundos")
