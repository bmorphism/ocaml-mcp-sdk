(* MCP Request and Response Types *)

open Mcp_types

(* Request Parameter Types *)
type initialize_params = {
  protocol_version : string;
  capabilities : client_capabilities;
  client_info : implementation;
}

type call_tool_params = {
  name : string;
  arguments : (string * string) list option;
}

type get_prompt_params = {
  name : string;
  arguments : (string * string) list option;
}

type read_resource_params = {
  uri : string;
}

type subscribe_params = {
  uri : string;
}

type list_params = {
  cursor : string option;
}

type completion_argument = {
  name : string;
  value : string;
}

type completion_context = {
  arguments : (string * string) list option;
}

type completion_params = {
  ref : completion_reference;
  argument : completion_argument;
  context : completion_context option;
}

type create_message_params = {
  messages : sampling_message list;
  max_tokens : int;
  system_prompt : string option;
  include_context : string option; (* "allServers", "none", "thisServer" *)
  temperature : float option;
  stop_sequences : string list option;
  metadata : (string * string) list option;
  model_preferences : model_preferences option;
}

type elicit_params = {
  message : string;
  requested_schema : elicit_schema;
}

type set_level_params = {
  level : logging_level;
}

type progress_params = {
  progress_token : progress_token;
  progress : float;
  total : float option;
  message : string option;
}

type cancelled_params = {
  request_id : request_id;
  reason : string option;
}

type roots_list_changed_params = unit

type resource_updated_params = {
  uri : string;
}

type logging_message_params = {
  level : logging_level;
  logger : string option;
  data : string; (* JSON serializable *)
}

(* Client Request Types *)
type client_request = 
  | Initialize of initialize_params
  | Ping
  | ListTools of list_params
  | CallTool of call_tool_params
  | ListResources of list_params
  | ListResourceTemplates of list_params
  | ReadResource of read_resource_params
  | Subscribe of subscribe_params
  | Unsubscribe of subscribe_params
  | ListPrompts of list_params
  | GetPrompt of get_prompt_params
  | Complete of completion_params
  | SetLevel of set_level_params

(* Server Request Types *)
type server_request = 
  | Ping
  | CreateMessage of create_message_params
  | ListRoots
  | Elicit of elicit_params

(* Client Notification Types *)
type client_notification = 
  | Initialized
  | Cancelled of cancelled_params
  | Progress of progress_params
  | RootsListChanged of roots_list_changed_params

(* Server Notification Types *)
type server_notification = 
  | Cancelled of cancelled_params
  | Progress of progress_params
  | ResourceListChanged
  | ResourceUpdated of resource_updated_params
  | PromptListChanged
  | ToolListChanged
  | LoggingMessage of logging_message_params

(* JSON-RPC Message Types *)
type request_meta = {
  progress_token : progress_token option;
}

type json_rpc_request = {
  jsonrpc : string; (* "2.0" *)
  id : request_id;
  method_name : string;
  params : (string * string) list option;
  meta : request_meta option;
}

type json_rpc_notification = {
  jsonrpc : string; (* "2.0" *)
  method_name : string;
  params : (string * string) list option;
  meta : (string * string) list option;
}

type json_rpc_response = {
  jsonrpc : string; (* "2.0" *)
  id : request_id;
  result : (string * string) list;
}

type error_info = {
  code : int;
  message : string;
  data : string option;
}

type json_rpc_error = {
  jsonrpc : string; (* "2.0" *)
  id : request_id;
  error : error_info;
}

type json_rpc_message = 
  | Request of json_rpc_request
  | Notification of json_rpc_notification
  | Response of json_rpc_response
  | Error of json_rpc_error
  | Batch of json_rpc_message list

(* Method name helpers *)
let method_name_of_client_request = function
  | Initialize _ -> "initialize"
  | Ping -> "ping"
  | ListTools _ -> "tools/list"
  | CallTool _ -> "tools/call"
  | ListResources _ -> "resources/list"
  | ListResourceTemplates _ -> "resources/templates/list"
  | ReadResource _ -> "resources/read"
  | Subscribe _ -> "resources/subscribe"
  | Unsubscribe _ -> "resources/unsubscribe"
  | ListPrompts _ -> "prompts/list"
  | GetPrompt _ -> "prompts/get"
  | Complete _ -> "completion/complete"
  | SetLevel _ -> "logging/setLevel"

let method_name_of_server_request = function
  | Ping -> "ping"
  | CreateMessage _ -> "sampling/createMessage"
  | ListRoots -> "roots/list"
  | Elicit _ -> "elicitation/create"

let method_name_of_client_notification = function
  | Initialized -> "notifications/initialized"
  | Cancelled _ -> "notifications/cancelled"
  | Progress _ -> "notifications/progress"
  | RootsListChanged _ -> "notifications/roots/list_changed"

let method_name_of_server_notification = function
  | Cancelled _ -> "notifications/cancelled"
  | Progress _ -> "notifications/progress"
  | ResourceListChanged -> "notifications/resources/list_changed"
  | ResourceUpdated _ -> "notifications/resources/updated"
  | PromptListChanged -> "notifications/prompts/list_changed"
  | ToolListChanged -> "notifications/tools/list_changed"
  | LoggingMessage _ -> "notifications/message"