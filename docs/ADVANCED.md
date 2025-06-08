# Advanced Patterns with OCaml MCP SDK

## Custom Effects

### Creating Your Own Effect

```ocaml
module Logger = struct
  type ('a, 'e) ops =
    | Log : string -> (unit, 'e) ops
    | SetLevel : [`Debug | `Info | `Warn | `Error] -> (unit, 'e) ops
    | GetLevel : ([`Debug | `Info | `Warn | `Error], 'e) ops

  include Effect.Make(struct type 'a t = ('a, t) ops end)
end

(* Use the logger effect *)
let with_logging f =
  Logger.run (fun logger ->
    Logger.perform logger (Log "Starting operation");
    let result = f () in
    Logger.perform logger (Log "Operation complete");
    result
  )
```

### Intercepting Protocol Operations

```ocaml
let rate_limited_protocol base_handler =
  let last_call = ref 0.0 in
  { Protocol.Result.handle = fun op k ->
      match op with
      | CallTool _ ->
          let now = Unix.gettimeofday () in
          if now -. !last_call < 1.0 then
            raise (Protocol_error "Rate limit exceeded");
          last_call := now;
          Protocol.Result.handle (Protocol.perform base_handler op) base_handler
      | _ ->
          Protocol.Result.handle (Protocol.perform base_handler op) base_handler
  }
```

## Error Recovery Patterns

### Retry with Exponential Backoff

```ocaml
let rec retry_with_backoff ~max_attempts ~delay op =
  let rec attempt n delay_ms =
    match Protocol.run (fun h -> Protocol.perform h op) with
    | Value v -> v
    | Exception e when n < max_attempts ->
        Unix.sleepf (float_of_int delay_ms /. 1000.0);
        attempt (n + 1) (delay_ms * 2)
    | Exception e -> raise e
    | Operation (op', k) ->
        (* Handle nested operations *)
        continue k (retry_with_backoff ~max_attempts ~delay op') []
  in
  attempt 1 delay
```

### Circuit Breaker Pattern

```ocaml
module CircuitBreaker = struct
  type state = Open | Closed | HalfOpen
  
  type t = {
    mutable state : state;
    mutable failures : int;
    mutable last_failure : float;
    threshold : int;
    timeout : float;
  }
  
  let create ~threshold ~timeout = {
    state = Closed;
    failures = 0;
    last_failure = 0.0;
    threshold;
    timeout;
  }
  
  let wrap_handler breaker base_handler =
    { Protocol.Result.handle = fun op k ->
        match breaker.state with
        | Open ->
            let now = Unix.gettimeofday () in
            if now -. breaker.last_failure > breaker.timeout then
              breaker.state <- HalfOpen
            else
              raise (Protocol_error "Circuit breaker open")
        | _ ->
            try
              let result = Protocol.perform base_handler op in
              if breaker.state = HalfOpen then begin
                breaker.state <- Closed;
                breaker.failures <- 0
              end;
              continue k result []
            with e ->
              breaker.failures <- breaker.failures + 1;
              breaker.last_failure <- Unix.gettimeofday ();
              if breaker.failures >= breaker.threshold then
                breaker.state <- Open;
              raise e
    }
end
```

## Testing Patterns

### Property-Based Testing with Effects

```ocaml
let test_protocol_idempotence () =
  QCheck.Test.make
    ~name:"Protocol operations are idempotent"
    QCheck.(pair string (list string))
    (fun (tool_name, params) ->
      let mock_handler = { Protocol.Result.handle = fun op k ->
        match op with
        | CallTool (name, _) when name = tool_name ->
            continue k (`Assoc [("result", `String "success")]) []
        | _ -> continue k (`Null) []
      } in
      
      (* Call twice, should get same result *)
      let result1 = Protocol.Result.handle 
        (Protocol.Value (Protocol.perform mock_handler (CallTool (tool_name, `Null))))
        mock_handler in
      let result2 = Protocol.Result.handle
        (Protocol.Value (Protocol.perform mock_handler (CallTool (tool_name, `Null))))
        mock_handler in
      
      result1 = result2
    )
```

### Mocking Complex Scenarios

```ocaml
let test_with_failure_injection () =
  let failure_points = ref [] in
  
  let failing_transport base = 
    { Transport.Result.handle = fun op k ->
        match op, !failure_points with
        | Send _, "send" :: rest ->
            failure_points := rest;
            raise (Transport_error "Simulated send failure")
        | Receive, "receive" :: rest ->
            failure_points := rest;
            raise (Transport_error "Simulated receive failure")
        | _ ->
            Transport.Result.handle (Transport.perform base op) base
    }
  in
  
  (* Test various failure scenarios *)
  failure_points := ["send"; "receive"; "send"];
  (* Run test with injected failures *)
```

## Performance Optimization

### Handler Caching

```ocaml
module CachedResource = struct
  type cache_entry = {
    content : Resource.contents;
    timestamp : float;
  }
  
  let cache = Hashtbl.create 16
  let ttl = 60.0 (* 1 minute *)
  
  let cached_handler base_handler =
    { Resource.Result.handle = fun op k ->
        match op with
        | Read uri ->
            let now = Unix.gettimeofday () in
            begin match Hashtbl.find_opt cache uri with
            | Some entry when now -. entry.timestamp < ttl ->
                continue k entry.content []
            | _ ->
                let content = Resource.perform base_handler (Read uri) in
                Hashtbl.replace cache uri { content; timestamp = now };
                continue k content []
            end
        | _ ->
            Resource.Result.handle (Resource.perform base_handler op) base_handler
    }
end
```

### Batch Operations

```ocaml
module BatchedProtocol = struct
  type batch = (string * Yojson.Safe.t) list
  
  let batch_handler ~flush_size base_handler =
    let pending = ref [] in
    let flush () =
      match !pending with
      | [] -> ()
      | batch ->
          let results = List.map (fun (name, params) ->
            Protocol.perform base_handler (CallTool (name, params))
          ) batch in
          pending := [];
          results
    in
    
    { Protocol.Result.handle = fun op k ->
        match op with
        | CallTool (name, params) ->
            pending := (name, params) :: !pending;
            if List.length !pending >= flush_size then
              let results = flush () in
              continue k (List.hd results) []
            else
              continue k (`Assoc [("batched", `Bool true)]) []
        | _ ->
            Protocol.Result.handle (Protocol.perform base_handler op) base_handler
    }
end
```

## Integration Patterns

### Combining with Lwt

```ocaml
let async_tool_handler name params =
  let open Lwt.Syntax in
  match name with
  | "fetch_url" ->
      let url = extract_url params in
      let* response = Cohttp_lwt_unix.Client.get (Uri.of_string url) in
      let* body = Cohttp_lwt.Body.to_string (snd response) in
      Lwt.return (`Assoc [("content", `String body)])
  | _ ->
      Lwt.fail (Method_not_found name)

let lwt_integrated_handler =
  { Tool.Result.handle = fun op k ->
      match op with
      | Call (name, params) ->
          let result = Lwt_main.run (async_tool_handler name params) in
          continue k result []
      | _ -> continue k [] []
  }
```

### Working with Existing Libraries

```ocaml
(* Integrate with Jane Street's Async *)
open Async

let async_resource_provider =
  let fetch_resource uri =
    match%bind fetch_from_database uri with
    | Ok content -> return (Resource.Text content)
    | Error _ -> return (Resource.Text "Not found")
  in
  
  { Resource.Result.handle = fun op k ->
      match op with
      | Read uri ->
          let content = Thread_safe.block_on_async_exn (fun () ->
            fetch_resource uri
          ) in
          continue k content []
      | _ -> continue k [] []
  }
```

## Debugging

### Effect Tracing

```ocaml
let trace_effects base_handler =
  let depth = ref 0 in
  let indent () = String.make (!depth * 2) ' ' in
  
  { Protocol.Result.handle = fun op k ->
      Printf.printf "%s→ %s\n" (indent ()) (operation_to_string op);
      incr depth;
      let result = Protocol.perform base_handler op in
      decr depth;
      Printf.printf "%s← %s\n" (indent ()) (result_to_string result);
      continue k result []
  }
```

### Performance Profiling

```ocaml
let profile_handler name base_handler =
  let timings = Hashtbl.create 16 in
  
  { Protocol.Result.handle = fun op k ->
      let start = Unix.gettimeofday () in
      let result = Protocol.perform base_handler op in
      let elapsed = Unix.gettimeofday () -. start in
      
      let op_name = operation_name op in
      let current = Hashtbl.find_opt timings op_name |> Option.value ~default:(0, 0.0) in
      Hashtbl.replace timings op_name (fst current + 1, snd current +. elapsed);
      
      continue k result []
  }
```