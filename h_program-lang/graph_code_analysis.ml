(* Yoann Padioleau
 *
 * Copyright (C) 2013 Facebook
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation, with the
 * special exception on linking described in file license.txt.
 * 
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
 * license.txt for more details.
 *)
open Common

module G = Graph_code
module E = Database_code

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)

(*****************************************************************************)
(* Main entry point *)
(*****************************************************************************)

(* It can be difficult to trace the use of a field in languages like
 * PHP because one can do $o->fld and you don't know the type of $o
 * and so its class. But for the protected_to_private analysis,
 * it means the field is protected and so it can be used only
 * via a $this->xxx expression, which is easy to statically 
 * analyze.
 *)
let protected_to_private g =
  g +> G.iter_nodes (fun node ->
    match node with
    | (s, E.Field) ->
      let props =
        try 
          let info = G.nodeinfo node g in
          info.G.props 
        with Not_found ->
          pr2 (spf "No nodeinfo for %s" (G.string_of_node node));
          [E.Privacy E.Private]
      in
      let privacy =
        props +> Common.find_some (function
        | E.Privacy x -> Some x
        | _ -> None
        )
      in
      (match privacy with
      | E.Private ->
        let users = G.pred node G.Use g in
        if null users
        then pr2 (spf "DEAD private field: %s" (G.string_of_node node))
      | E.Protected ->
        let class_ = G.parent node g in
        let classname = fst class_ in

        let users = G.pred node G.Use g in
        if null users
        then pr2 (spf "DEAD protected field: %s" (G.string_of_node node))
        else 
          if users +> List.for_all (fun (s, kind) -> 
            s =~ (spf "^%s\\." classname)
          )
          then pr2 (spf "Protected to private candidate: %s"
                      (G.string_of_node node))
          else ()
          
      | _ -> ()
      )
    | _ -> ()
  )
