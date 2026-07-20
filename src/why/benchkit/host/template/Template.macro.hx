package why.benchkit.host.template;

import haxe.macro.Context;
import haxe.macro.MacroStringTools;
import sys.io.File;

using haxe.io.Path;

class Template {
	public static function load(file:String) {
		return MacroStringTools.formatString(File.getContent(Context.getPosInfos((macro null).pos).file.directory() + '/$file'), Context.currentPos());
	}
}
