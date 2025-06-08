(* Minimal Basement stub for oxcaml_effect *)

module Stdlib_shim = struct
  module Obj = struct
    let magic_unique x = Obj.magic x
    let magic_at_unique x = Obj.magic x
    let magic_portable x = Obj.magic x
    let magic_uncontended x = Obj.magic x
  end
  
  let runtime5 () = 
    let version = Sys.ocaml_version in
    String.length version > 0 && version.[0] = '5'
  
  let raise_notrace = raise
end

module Callback = struct
  module Safe = struct
    let register_exception name exn = 
      Callback.register_exception name exn
  end
end