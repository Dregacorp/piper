let iterations = 3_000_000

let repeats = 9

let input_count = 1024


let expected2 = 26_756_370_240L

let expected3 = 324_207_267_022_400L

let expected4 = -324_207_267_022_400L


let[@inline never] double_f (x : int64) : int64 =
  Int64.mul x 2L


let[@inline never] add_one_f (x : int64) : int64 =
  Int64.add x 1L


let[@inline never] square_f (x : int64) : int64 =
  Int64.mul x x


let[@inline never] negate_f (x : int64) : int64 =
  Int64.neg x


let inputs : int64 array =
  Array.init
    input_count
    (fun i ->
      Int64.of_int
        (((i * 17) + 31) mod 10_000))


let composed2 =
  Fun.compose
    add_one_f
    double_f


let composed3 =
  Fun.compose
    square_f
    (Fun.compose
       add_one_f
       double_f)


let composed4 =
  Fun.compose
    negate_f
    (Fun.compose
       square_f
       (Fun.compose
          add_one_f
          double_f))


let direct2 () : int64 =
  let total = ref 0L in

  for i = 0 to iterations - 1 do
    let x =
      inputs.(i land (input_count - 1))
    in

    total :=
      Int64.add
        !total
        (add_one_f
           (double_f x))
  done;

  !total


let direct3 () : int64 =
  let total = ref 0L in

  for i = 0 to iterations - 1 do
    let x =
      inputs.(i land (input_count - 1))
    in

    total :=
      Int64.add
        !total
        (square_f
           (add_one_f
              (double_f x)))
  done;

  !total


let direct4 () : int64 =
  let total = ref 0L in

  for i = 0 to iterations - 1 do
    let x =
      inputs.(i land (input_count - 1))
    in

    total :=
      Int64.add
        !total
        (negate_f
           (square_f
              (add_one_f
                 (double_f x))))
  done;

  !total


let pipe2 () : int64 =
  let total = ref 0L in

  for i = 0 to iterations - 1 do
    let x =
      inputs.(i land (input_count - 1))
    in

    let value =
      x
      |> double_f
      |> add_one_f
    in

    total :=
      Int64.add
        !total
        value
  done;

  !total


let pipe3 () : int64 =
  let total = ref 0L in

  for i = 0 to iterations - 1 do
    let x =
      inputs.(i land (input_count - 1))
    in

    let value =
      x
      |> double_f
      |> add_one_f
      |> square_f
    in

    total :=
      Int64.add
        !total
        value
  done;

  !total


let pipe4 () : int64 =
  let total = ref 0L in

  for i = 0 to iterations - 1 do
    let x =
      inputs.(i land (input_count - 1))
    in

    let value =
      x
      |> double_f
      |> add_one_f
      |> square_f
      |> negate_f
    in

    total :=
      Int64.add
        !total
        value
  done;

  !total


let compose_run
    (pipeline : int64 -> int64)
    : int64 =

  let total = ref 0L in

  for i = 0 to iterations - 1 do
    let x =
      inputs.(i land (input_count - 1))
    in

    total :=
      Int64.add
        !total
        (pipeline x)
  done;

  !total


external monotonic_ns : unit -> int64 =
  "piper_clock_monotonic_ns"


let median
    (values : int64 array)
    : int64 =

  let copy =
    Array.copy values
  in

  Array.sort compare copy;

  copy.(repeats / 2)


let measure
    (name : string)
    (f : unit -> int64) =

  ignore (f ());

  for _ = 1 to 3 do
    ignore (f ())
  done;

  let samples =
    Array.init
      repeats
      (fun _ ->
        let started =
          monotonic_ns ()
        in

        let result =
          f ()
        in

        let finished =
          monotonic_ns ()
        in

        ignore result;

        Int64.sub
          finished
          started)
  in

  let median_ns =
    median samples
  in

  let ns_per_op =
    Int64.to_float median_ns
    /. float_of_int iterations
  in

  let checksum =
    f ()
  in

  Printf.printf
    "RESULT,OCaml,%s,%.6f,%Ld\n%!"
    name
    ns_per_op
    checksum


let () =
  if direct2 () <> expected2 then
    failwith "direct2 checksum mismatch";

  if direct3 () <> expected3 then
    failwith "direct3 checksum mismatch";

  if direct4 () <> expected4 then
    failwith "direct4 checksum mismatch";

  if composed2 7L <> add_one_f (double_f 7L) then
    failwith "compose2 correctness failure";

  if composed3 7L <>
     square_f
       (add_one_f
          (double_f 7L))
  then
    failwith "compose3 correctness failure";

  if composed4 7L <>
     negate_f
       (square_f
          (add_one_f
             (double_f 7L)))
  then
    failwith "compose4 correctness failure";

  Printf.printf
    "VERSION,OCaml,%s\n%!"
    Sys.ocaml_version;

  measure "direct2" direct2;

  measure "pipe2" pipe2;

  measure
    "compose2"
    (fun () ->
      compose_run composed2);

  measure "direct3" direct3;

  measure "pipe3" pipe3;

  measure
    "compose3"
    (fun () ->
      compose_run composed3);

  measure "direct4" direct4;

  measure "pipe4" pipe4;

  measure
    "compose4"
    (fun () ->
      compose_run composed4)