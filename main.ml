(*
 * Please imagine a long and boring gnu-style copyright notice 
 * appearing just here.
 *)
open Common

(*****************************************************************************)
(* Purpose *)
(*****************************************************************************)
(*  
 * A "driver" for the different parsers in pfff.
 *)

(*****************************************************************************)
(* Flags *)
(*****************************************************************************)

(* In addition to flags that can be tweaked via -xxx options (cf the
 * full list of options in the "the options" section below), this 
 * program also depends on external files ?
 *)

let verbose = ref false

let lang = ref "c"

(* action mode *)
let action = ref ""

(*****************************************************************************)
(* Some debugging functions *)
(*****************************************************************************)

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

(*****************************************************************************)
(* Main action *)
(*****************************************************************************)
let main_action _xs = 
  raise Todo 

(*****************************************************************************)
(* LPizer *)
(*****************************************************************************)

(* for lpification, to get a list of files and handling the skip list *)
let find_source xs =
  let root = Common2.common_prefix_of_files_or_dirs xs in
  let root = Common.realpath root +> Common2.chop_dirsymbol in
  let files = 
    Find_source.files_of_dir_or_files ~lang:!lang ~verbose:!verbose xs in
  files +> List.iter (fun file ->
    pr (Common.readable root file)
  )

(* syncweb does not like tabs *)
let untabify s =
  Str.global_substitute (Str.regexp "^\\([\t]+\\)") (fun _wholestr ->
    let substr = Str.matched_string s in
    let n = String.length substr in
    Common2.n_space (4 * n)
  ) s

(* todo: could generalize this in graph_code.ml! have a range
 * property there!
 *)
type entity = {
  name: string;
  kind: Entity_code.entity_kind;
  range: int * int;
}

open Ast_cpp
module Ast = Ast_cpp
module E = Entity_code
module PI = Parse_info

let hooks_for_comment = { Comment_code.
    kind = Token_helpers_cpp.token_kind_of_tok;
    tokf = Token_helpers_cpp.info_of_tok;
                        }

let range_of_any_with_comment any toks =
  let ii = Lib_parsing_cpp.ii_of_any any in
  let (min, max) = PI.min_max_ii_by_pos ii in
  match Comment_code.comment_before hooks_for_comment min toks with
  | None -> min, max
  | Some ii -> ii, max
  

let extract_entities xs =
  xs +> Common.map_filter (fun (top, toks) ->
    match top with
    | DeclElem decl ->
      (match decl with
      | Func (FunctionOrMethod def) ->
        let (min, max) = range_of_any_with_comment (Toplevel top) toks in
        Some { 
          name = Ast.string_of_name_tmp def.f_name;
          kind = E.Function;
          range = (PI.line_of_info min, PI.line_of_info max);
        }
      | _ -> None
      )
    | _ -> None
  )

let sanity_check _xs =
(*
  let group_by_basename =
    xs +> List.map (fun file -> Filename.basename file, file)
    +> Common.group_assoc_bykey_eff
  in
  group_by_basename +> List.iter (fun (_base, xs) ->
    if List.length xs > 1
    then pr2 (spf "multiple files with same name: %s" 
                     (xs +> Common.join "\n"))
  );
*)
  ()

let string_of_entity_kind kind =
  match kind with
  | E.Function -> "function"
  | _ -> failwith (spf "not handled kind: %s" (E.string_of_entity_kind kind))

(* main entry point *)
let lpize xs = 
  Parse_cpp.init_defs !Flag_parsing_cpp.macros_h;

  sanity_check xs;
  let current_dir = ref "" in

  xs +> List.iter (fun file ->
    let dir = Filename.dirname file in
    if dir <> !current_dir
    then begin
      pr (spf "\\section{[[%s/]]}" dir);
      pr "";
      current_dir := dir;
    end;

    pr (spf "\\subsection*{[[%s]]}" file);
    pr "";

    let (xs, _stat) = Parse_cpp.parse file in
    let entities = extract_entities xs in

    let hstart = 
      entities +> List.map (fun e -> fst e.range, e) +> Common.hash_of_list
    in
    let hcovered = 
      entities +> List.map (fun e -> 
        let (lstart, lend) = e.range in
        Common2.enum_safe lstart lend
      ) +> List.flatten +> Common.hashset_of_list
    in
    
    let lines = Common.cat file in
    let arr = Array.of_list lines in

    (* the chunks *)
    entities +> List.iter (fun e ->
        let (lstart, lend) = e.range in
        pr (spf "<<%s %s>>=" (string_of_entity_kind e.kind) e.name);

        Common2.enum_safe lstart lend +> List.iter (fun line ->
          let idx = line - 1 in
          if idx >= Array.length arr || idx < 0
          then failwith (spf "out of range for %s, line %d" file line);
          pr (untabify (arr.(line - 1)))
        );
        pr "@";
        pr "";
    );

    (* we don't use the basename (even though 'make sync' ' used to make
     * this assumption because) because we would have too many dupes.
     *)
    pr (spf "<<%s>>=" file);
    Common.cat file +> Common.index_list_1 +> List.iter (fun (s, idx) ->
      match Common2.hfind_option idx hstart with
      | None -> 
          if Hashtbl.mem hcovered idx
          then ()
          else pr (untabify s)
      | Some e -> 
        pr (spf "<<%s %s>>" (string_of_entity_kind e.kind) e.name);
    );
    pr "@";
    pr "";
    pr "";

    (* for the initial 'make sync' to work *)
    (* Sys.command (spf "rm -f %s" file) +> ignore; *)
  );
  ()

(*****************************************************************************)
(* Extra Actions *)
(*****************************************************************************)
let test_json_pretty_printer file =
  let json = Json_in.load_json file in
  let s = Json_io.string_of_json json in
  pr s



(* ---------------------------------------------------------------------- *)
let pfff_extra_actions () = [
  "-dump_json", " <file>",
  Common.mk_action_1_arg test_json_pretty_printer;
  "-json_pp", " <file>",
  Common.mk_action_1_arg test_json_pretty_printer;
  "-layer_stat", " <file>",
  Common.mk_action_1_arg Test_program_lang.layer_stat;
  "-find_source", " <dirs>",
  Common.mk_action_n_arg find_source;
  "-lpize", " <files>",
  Common.mk_action_n_arg lpize;
  
]

(*****************************************************************************)
(* The options *)
(*****************************************************************************)

let all_actions () = 
  pfff_extra_actions() @
  Test_parsing_ml.actions()@

  Test_parsing_php.actions()@
  Test_parsing_js.actions()@

  Test_parsing_c.actions()@
  Test_parsing_cpp.actions()@
  Test_parsing_clang.actions()@
  Test_mini.actions()@
(*
  Test_parsing_bytecode.actions()++
*)
  Test_parsing_java.actions()@

  Test_parsing_nw.actions()@

  Test_parsing_lisp.actions()@
  Test_parsing_hs.actions()@

  Test_parsing_python.actions()@
  Test_parsing_csharp.actions()@

  Test_parsing_rust.actions()@
  Test_parsing_erlang.actions()@

  Test_parsing_text.actions()@
  Test_parsing_html.actions()@
  Test_parsing_css.actions()@
  Test_parsing_web.actions()@

  Test_parsing_opa.actions()@
  Test_parsing_sql.actions()@

(*
  Test_analyze_cpp.actions () ++
  Test_analyze_php.actions () ++
  Test_analyze_ml.actions () ++
  Test_analyze_clang.actions () ++
  Test_analyze_c.actions() ++
*)
  []


let options () = [
  "-verbose", Arg.Set verbose, 
  " ";
  "-lang", Arg.Set_string lang, 
  (spf " <str> choose language (default = %s)" !lang);
  ] @
  Flag_parsing_php.cmdline_flags_verbose () @
  Flag_parsing_cpp.cmdline_flags_verbose () @

  Flag_parsing_php.cmdline_flags_debugging () @
  Flag_parsing_cpp.cmdline_flags_debugging () @

  Flag_parsing_php.cmdline_flags_pp () @
  Flag_parsing_cpp.cmdline_flags_macrofile () @

  Common.options_of_actions action (all_actions()) @
  Common2.cmdline_flags_devel () @
  Common2.cmdline_flags_other () @
  [
    "-version",   Arg.Unit (fun () -> 
      pr2 (spf "pfff version: %s" Config_pfff.version);
      exit 0;
    ), "  guess what";
  ]


(*****************************************************************************)
(* Main entry point *)
(*****************************************************************************)

let main () = 

  Gc.set {(Gc.get ()) with Gc.stack_limit = 1000 * 1024 * 1024};
  (* Common_extra.set_link(); 
     let argv = Features.Distribution.mpi_adjust_argv Sys.argv in
  *)

  let usage_msg = 
    "Usage: " ^ Common2.basename Sys.argv.(0) ^ 
      " [options] <file or dir> " ^ "\n" ^ "Options are:"
  in
  (* does side effect on many global flags *)
  let args = Common.parse_options (options()) usage_msg Sys.argv in

  (* must be done after Arg.parse, because Common.profile is set by it *)
  Common.profile_code "Main total" (fun () -> 
    
    (match args with
    
    (* --------------------------------------------------------- *)
    (* actions, useful to debug subpart *)
    (* --------------------------------------------------------- *)
    | xs when List.mem !action (Common.action_list (all_actions())) -> 
        Common.do_action !action xs (all_actions())

    | _ when not (Common.null_string !action) -> 
        failwith ("unrecognized action or wrong params: " ^ !action)

    (* --------------------------------------------------------- *)
    (* main entry *)
    (* --------------------------------------------------------- *)
    | x::xs -> 
        main_action (x::xs)
          
    (* --------------------------------------------------------- *)
    (* empty entry *)
    (* --------------------------------------------------------- *)
    | [] -> 
        Common.usage usage_msg (options()); 
        failwith "too few arguments"
    )
  )

(*****************************************************************************)
let _ =
  Common.main_boilerplate (fun () -> 
    main ();
  )
