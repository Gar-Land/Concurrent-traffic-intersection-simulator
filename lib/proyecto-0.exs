defmodule Proyecto do
  # funcion que calcula el promedio de tiempo de alguna calle, pimero calcula el promedio
  # de cada carril mapeandolo y luego la lista de promedios resultante se suma y se dividide por
  # la cantidad de carriles
  defp avg_t(street) do
    Enum.map(street, fn lane -> Enum.sum(lane)/length(lane) end)
    |> Enum.sum() |> Kernel./(length(street))
  end

  # funcion que calcula el número de vehículos sobre alguna calle
  defp numberOfCars(street) do
    Enum.reduce(street, 0, fn lane, acc -> acc + length(lane) end)
  end

  # función que calcula el tiempo de espera de cada vehículo para poder cruzar
  defp trigger(cars, tl, ft) do
    cycle = tl["g"] + tl["y"] + tl["r"] # se inicializa variable por motivos de legibilidad y eficiencia
    window = tl["g"] + tl["y"]          # se inicializa variable por motivos de legibilidad y eficiencia
    red = tl["r"]                       # se inicializa variable por motivos de legibilidad y eficiencia
    Enum.map(cars, fn car ->
      # quotient = div(car, cycle)        # se inicializa variable por motivos de legibilidad y eficiencia
      rem = rem(car, cycle)             # se inicializa variable por motivos de legibilidad y eficiencia
      cond do
        0 <= car && car <= window -> # Pasa en seguida porque su tiempo de llegada es menor a la suma de
        # los estados verde y amarillo
          IO.puts("pasa en seguida")
          car + ft
        window < car && car <= cycle -> # cuando llega despues de la suma de los estados verde y amarillo
        # y pasará en cycle mod car segundos
          IO.puts("no pasa, pasará en #{rem(cycle, car)}s")
          rem(cycle, car) + ft
        cycle < car && rem <= window -> # cuando llega después del primer ciclo, y car mod cycle es menor
        # o igual que la suma los estados verde y amarillo. Pasará después de car div cycle ciclos
          IO.puts("no pasa en #{quotient} ciclo(s), pasará en #{rem}s")
          rem + ft
        cycle < car && rem > window ->  # cuando llega después del primer ciclo, y car mod cycle es mayor
        # que la suma los estados verde y amarillo. Pasará después de ciertos segundos porque llegó cuando
        # el semáforo estaba en rojo
          IO.puts("no pasa en #{quotient} ciclo(s), pasará en #{red - (rem - window)}s")
          red - (rem - window) + ft
      end
    end)
  end

  # funcion que parsea la string de tiempos de llegada de los vehículos de
  # algún carril a un arreglo de enteros, resulta que este acercamiento es más eficiente
  # que usar Code.eval_string/2 el equivalente de Elixir a eval de Scheme/Racket
  defp to_list(times), do: String.split(times, ", ") |> Enum.map(&String.to_integer(&1))

  # función que se encarga de abrir, leer, escribir en los distitos archivos,
  # también invoca las funciones que realizan cálculos. Básicamente administra al
  # simulador
  def calc_stats(sif, sof, ds) do
    IO.puts("LECTURA DE LOS TIEMPOS DE CRUCE DE CADA VEHÍCULO POR CARRIL INICIALIZADA\n")

    {map_1, map_2} = ds # Obtiene las estructura de datos correspondiente a cada calle

    {:ok, output_f} = File.open(sof, [:write]) # Abre el archivo de salida en modo escritura
    # (para poder escribir) y se extrae su dirección en output_f

    lanes = File.read(sif) |> elem(1) |> String.split("\r\n", trim: true) # Extrae en una
    # lista el contenido del los tiempos de llegada que son divididos por "\r\n"

    {st_1, st_2} = Enum.split(lanes, div(length(lanes), 2)) # Extrae de una tupla cada
    # elemento (los carriles que le corresponden a una calle) de la tupla

    {write_lane, write_stats} = { # almacena dos funciones anónimas encargadas de
    # escribir en el archivo de salida
      fn lane, of ->
      IO.binwrite(of, Enum.join(lane, ", ")<>"\r\n")
      lane
      end,
      fn st, of ->
        IO.puts("CALCULO DE ESTADISTICAS INICIALIZADO")
        {total_cars, avg_t} = {numberOfCars(st), avg_t(st)}
        IO.binwrite(of, "Numero de vehículos sobre la calle: #{total_cars}")
        IO.binwrite(of, "\tTiempo promedio en cruzar la calle: #{avg_t}\r\n")
        IO.puts("CALCULO DE ESTADISTICAS FINALIZADO\n")
        {total_cars, avg_t}
      end
    }

    IO.puts("CALCULO DE LOS TIEMPOS DE CRUCE INICIALIZADO\n")
    # Manda a llamr las funciones que obtienen los cálculos y escribe los
    # resultados en output_f
    st_1 = st_1
    |> Enum.map(fn lane -> to_list(lane)
    |> trigger(map_1.tl, map_1.f_time)
    |> write_lane.(output_f) end) # Escribe sobre el archivo se salida
    IO.puts("\nCALCULO DE LOS TIEMPOS DE CRUCE FINALIZADO\n")
    {cars_1, avg_t_1} = write_stats.(st_1, output_f) # Escribe sobre el
    # archivo de salida y retorna los cálculos

    IO.puts("CALCULO DE LOS TIEMPOS DE CRUCE INICIALIZADO\n")
    # Manda a llamr las funciones que obtienen los cálculos y escribe los
    # resultados en output_f
    st_2 = st_2
    |> Enum.map(fn lane -> to_list(lane)
    |> trigger(map_2.tl, map_2.f_time)
    |> write_lane.(output_f) end) # Escribe sobre el archivo se salida
    IO.puts("\nCALCULO DE LOS TIEMPOS DE CRUCE FINALIZADO\n")
    {cars_2, avg_t_2} = write_stats.(st_2, output_f) # Escribe sobre el
    # archivo de salida y retorna los cálculos

    IO.binwrite(output_f, "\nNúmero de vehículos en el crucero: #{cars_1 + cars_2}\t")
    IO.binwrite(output_f, "Tiempo promedio en cruzar el crucero: #{(avg_t_1 + avg_t_2) / tuple_size(ds)}\r\n")
    File.close(output_f) # Cierra el archivo de salida ya que se ha escrito todo
    IO.puts("LECTURA DE LOS TIEMPOS DE CRUCE DE CADA VEHÍCULO POR CARRIL FINALIZADA\n")
  end
end

# Parsea la estrucutra de datos del archivo de entrada que la
# contiene. Toda función con nombre tiene que ir dentro de un
# módulo
defmodule DataStructure do
  defp parsed_ds(list, function, tls \\ {0, 0}, f_times \\ {0, 0}) do
    # Manejo de errores en caso de que no sea un estructura
    # válida
    if !Regex.match?(~r<^%{tl: \[g: \d+, y: \d+, r: \d+\]}>, hd(list)) do
      raise("Error: #{hd(list)} no es una estrucutra de datos adecuada para modelar una calle")
    end
    # Obtiene el hashmap con la configuración del semáforo
    tl = Regex.named_captures(~r/g: (?<g>\d+), y: (?<y>\d+), r: (?<r>\d+)/, hd(list))
    # Acualiza sus valores de representaciones string a
    # sus representaciones enteras, pero tiene que pasar
    # por una mutación
    tl = Map.put(tl, "g", String.to_integer(tl["g"]))
      |> Map.put("y", String.to_integer(tl["y"]))
      |> Map.put("r", String.to_integer(tl["r"]))
    rem_tks = function.(list) # Pasa al siguiente token,
    # pero tiene que pasar por una mutacíon

    # Manejo de errores en caso de que la estructura no
    # sea seguida por un número entero
    if !Regex.match?(~r<\d+>, hd(rem_tks)) do
      raise("Error: cada estructura de datos tiene que ser seguida por un número entero")
    end
    f_time = String.to_integer(hd(rem_tks))
    rem_tks = function.(rem_tks) # Pasa el siguiente
    # token, pero tiene que pasar por una mutacíon

    if (rem_tks != []) do # Si siguen habiendo tokens,
    # la funcion vuelve a llamarse
      parsed_ds(rem_tks, function, put_elem(tls, 0, tl), put_elem(f_times, 0, f_time))
    else # Se retorna la estructura de datos
      IO.puts("LECTURA DE LA ESTRUCTURA DE DATOS FINALIZADA\n")
      tls = put_elem(tls, 1, tl)
      f_times = put_elem(f_times, 1, f_time)
      { %{tl: elem(tls, 0), f_time: elem(f_times, 0)},
        %{tl: elem(tls, 1), f_time: elem(f_times, 1)} }
    end
  end

  # Función anónima que se encarga de extraer el contenido
  # del archivo (contiene la estrucutra de datos) y
  # dividirlo en tokens
  def get_ds_from_txt(path) do
    case File.read(path) do
      {:ok, content} ->
        IO.puts("LECTURA DE LA ESTRUCTURA DE DATOS SOBRE INICIALIZADA")
        String.split(content, ["\r\n", ", tiempo fijo: "]) -- [""]
        |> parsed_ds(fn [_head | tail] -> tail end)
        # Se manda a llamar parsed_ds que toma como
        # argumento a los tokens
      {:error, :enoent} -> # Manejo de errores en
      # caso de que no exista dicha dirección
        raise("Error: Nningún archivo o directorio fue encontrado en #{path}")
    end
  end
end

{ds_f, cif, cof} = {"data-structure.txt", "cars.txt", "calculated-times-0.txt"}
# Ajusta el directorio actual

File.cd("./tests/test_data")
{:ok, path} = File.cwd() # Se extrea la representacíon
# string del directorio actual y es almacenada en path

run_full_simulation = fn ->
  IO.puts("SIMULADOR DEL CRUCERO INICIALIZADO\n")
  ds = DataStructure.get_ds_from_txt(Path.join(path , ds_f)) # Se manda a llamar
  # la función que obtiene la estructura de datos

  Proyecto.calc_stats(Path.join(path, cif), Path.join(path, cof), ds)
  # Se manda a llamar la función que administra al simulador
  IO.puts("ARCHIVO TXT DE SALIDA YA ESTÁ DISPONIBLE")
  IO.puts("SIMULADOR DEL CRUCERO FINALIZADO")
end

{time, _result} = :timer.tc(run_full_simulation)
IO.puts("Tiempo de ejecución: #{time / 1000000} segundos")
