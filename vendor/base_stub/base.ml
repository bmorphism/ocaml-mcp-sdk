(* Minimal Base stub for oxcaml_effect *)

module Modes = struct
  module Aliased = struct
    type 'a t = { aliased : 'a }
  end
  
  module Portable = struct
    type 'a t = 'a
  end
end

module Type = struct
  type ('a, 'b) eq = Equal : ('a, 'a) eq
end

module Int = struct
  let equal = (=)
end

module Exn = struct
  type t = exn
end

module Backtrace = struct
  type t = Printexc.raw_backtrace
end

let phys_equal = (==)

(* Annotations used by oxcaml_effect *)
let ( @@ ) f x = f x