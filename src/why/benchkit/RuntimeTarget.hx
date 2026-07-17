package why.benchkit;

/**
	Compile-time target id for suite JSON (`target` field).
	Names align with travix host target commands where possible.
**/
class RuntimeTarget {
	function new() {}

	public static function name():String {
		#if interp
		return "interp";
		#elseif neko
		return "neko";
		#elseif python
		return "python";
		#elseif (js && nodejs)
		return "node";
		#elseif js
		return "js";
		#elseif lua
		return "lua";
		#elseif cpp
		return "cpp";
		#elseif jvm
		return "jvm";
		#elseif java
		return "java";
		#elseif cs
		return "cs";
		#elseif hl
		return "hl";
		#elseif php
		return "php";
		#else
		return "unknown";
		#end
	}
}
