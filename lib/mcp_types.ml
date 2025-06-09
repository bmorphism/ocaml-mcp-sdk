(* Complete MCP Protocol Types based on JSON Schema *)

open Printf

(* Core JSON-RPC Types *)
type request_id = 
  | String of string 
  | Int of int

type progress_token = 
  | String of string 
  | Int of int

(* Roles *)
type role = 
  | User 
  | Assistant

(* Logging Levels *)
type logging_level = 
  | Emergency | Alert | Critical | Error 
  | Warning | Notice | Info | Debug

(* Annotations *)
type annotations = {
  audience : role list option;
  priority : float option; (* 0.0 to 1.0 *)
}

(* Content Types *)
type text_content = {
  text : string;
  annotations : annotations option;
}

type image_content = {
  data : string; (* base64 *)
  mime_type : string;
  annotations : annotations option;
}

type audio_content = {
  data : string; (* base64 *)
  mime_type : string;
  annotations : annotations option;
}

type text_resource_contents = {
  uri : string;
  text : string;
  mime_type : string option;
}

type blob_resource_contents = {
  uri : string;
  blob : string; (* base64 *)
  mime_type : string option;
}

type resource_contents = 
  | Text of text_resource_contents
  | Blob of blob_resource_contents

type embedded_resource = {
  resource : resource_contents;
  annotations : annotations option;
}

type content = 
  | Text of text_content
  | Image of image_content  
  | Audio of audio_content
  | Resource of embedded_resource

(* Schema Types *)
type string_schema = {
  title : string option;
  description : string option;
  min_length : int option;
  max_length : int option;
  format : string option; (* date, date-time, email, uri *)
}

type number_schema = {
  title : string option;
  description : string option;
  minimum : int option;
  maximum : int option;
}

type boolean_schema = {
  title : string option;
  description : string option;
  default : bool option;
}

type enum_schema = {
  title : string option;
  description : string option;
  enum_values : string list;
  enum_names : string list option;
}

type primitive_schema = 
  | String of string_schema
  | Number of number_schema
  | Boolean of boolean_schema
  | Enum of enum_schema

(* Implementation Info *)
type implementation = {
  name : string;
  version : string;
}

(* Model Preferences *)
type model_hint = {
  name : string option;
}

type model_preferences = {
  hints : model_hint list option;
  cost_priority : float option; (* 0.0 to 1.0 *)
  speed_priority : float option; (* 0.0 to 1.0 *)
  intelligence_priority : float option; (* 0.0 to 1.0 *)
}

(* Tools *)
type tool_annotations = {
  title : string option;
  read_only_hint : bool option;
  destructive_hint : bool option;
  idempotent_hint : bool option;
  open_world_hint : bool option;
}

type input_schema = {
  schema_type : string; (* "object" *)
  properties : (string * primitive_schema) list option;
  required : string list option;
}

type tool_def = {
  name : string;
  description : string option;
  input_schema : input_schema;
  output_schema : input_schema option;
  annotations : tool_annotations option;
}

(* Resources *)
type resource = {
  uri : string;
  name : string;
  description : string option;
  mime_type : string option;
  size : int option;
  annotations : annotations option;
}

type resource_template = {
  uri_template : string;
  name : string;
  description : string option;
  mime_type : string option;
  annotations : annotations option;
}

(* Prompts *)
type prompt_argument = {
  name : string;
  description : string option;
  required : bool option;
}

type prompt = {
  name : string;
  description : string option;
  arguments : prompt_argument list option;
}

type prompt_message = {
  role : role;
  content : content;
}

(* Roots *)
type root = {
  uri : string;
  name : string option;
}

(* Capabilities *)
type client_capabilities = {
  roots : (bool option) option; (* listChanged *)
  sampling : bool option;
  elicitation : bool option;
  experimental : (string * bool) list option;
}

type server_capabilities = {
  tools : (bool option) option; (* listChanged *) 
  resources : (bool option * bool option) option; (* listChanged, subscribe *)
  prompts : (bool option) option; (* listChanged *)
  logging : bool option;
  completions : bool option;
  experimental : (string * bool) list option;
}

(* Messages *)
type sampling_message = {
  role : role;
  content : content;
}

type elicit_schema = {
  schema_type : string; (* "object" *)
  properties : (string * primitive_schema) list;
  required : string list option;
}

(* References *)
type prompt_reference = {
  ref_type : string; (* "ref/prompt" *)
  name : string;
}

type resource_template_reference = {
  ref_type : string; (* "ref/resource" *)
  uri : string;
}

type completion_reference = 
  | Prompt of prompt_reference
  | Resource of resource_template_reference

(* Result Types *)
type meta_info = (string * string) list

type result_base = {
  meta : meta_info option;
}

type list_tools_result = {
  base : result_base;
  tools : tool_def list;
  next_cursor : string option;
}

type call_tool_result = {
  base : result_base;
  content : content list;
  is_error : bool option;
  structured_content : (string * string) list option;
}

type list_resources_result = {
  base : result_base;
  resources : resource list;
  next_cursor : string option;
}

type read_resource_result = {
  base : result_base;
  contents : resource_contents list;
}

type list_prompts_result = {
  base : result_base;
  prompts : prompt list;
  next_cursor : string option;
}

type get_prompt_result = {
  base : result_base;
  description : string option;
  messages : prompt_message list;
}

type initialize_result = {
  base : result_base;
  protocol_version : string;
  capabilities : server_capabilities;
  server_info : implementation;
  instructions : string option;
}

type completion_result = {
  base : result_base;
  values : string list;
  total : int option;
  has_more : bool option;
}

type create_message_result = {
  base : result_base;
  role : role;
  content : content;
  model : string;
  stop_reason : string option;
}

type list_roots_result = {
  base : result_base;
  roots : root list;
}

type elicit_result = {
  base : result_base;
  action : string; (* accept, decline, cancel *)
  content : (string * string) list option;
}

(* Pretty printing helpers *)
let string_of_role = function
  | User -> "user"
  | Assistant -> "assistant"

let string_of_logging_level = function
  | Emergency -> "emergency" | Alert -> "alert" | Critical -> "critical" 
  | Error -> "error" | Warning -> "warning" | Notice -> "notice"
  | Info -> "info" | Debug -> "debug"

let string_of_request_id = function
  | String s -> s
  | Int i -> string_of_int i

let string_of_progress_token = function
  | String s -> s
  | Int i -> string_of_int i