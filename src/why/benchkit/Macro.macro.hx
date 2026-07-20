package why.benchkit;

import haxe.macro.Context;

using haxe.io.Path;
using StringTools;

function sourcePath() {
	return macro $v{Context.getPosInfos(Context.currentPos()).file.replace('//', '/').normalize()}
}
