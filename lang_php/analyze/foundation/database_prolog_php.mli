
val build:
  ?show_progress:bool ->
  Graph_code.graph -> Graph_code_prolog.fact list

val append_callgraph_to_prolog_db:
  ?show_progress:bool ->
  Callgraph_php2.callgraph -> Common.filename -> unit

(* used for testing purpose mostly *)
val prolog_query:
  ?verbose:bool -> source_file:Common.filename -> query:string -> 
  (* prolog output *)
  string list
