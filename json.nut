fe.load_module( "file" );

local file;
local txt;

function json_callback(output)
{
  file.write_line(output);
}

function text_callback(output)
{
  txt += output;
}

function json_output(command, args)
{
  file = WriteTextFile( "/tmp/json.nut" );
  file.write_line("return ");
  print("Running command: " + command + " " + args + "\n");
  fe.plugin_command(command, args, "json_callback");
	file._f.close();
  return dofile( "/tmp/json.nut", true );
}

function text_output(command, args)
{
  txt = "";
  print("Running command: " + command + " " + args + "\n");
  fe.plugin_command(command, args, "text_callback");
  return txt;
}
