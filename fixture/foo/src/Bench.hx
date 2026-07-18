package;

import why.benchkit.Runner;

class Bench {
	public static function main():Void {
		Runner.run([
			new MyLibSuite(),
		]);
	}
}

@:name("my_lib")
class MyLibSuite {
	public function new() {}

	@:name("op.name")
	@:warmup(100)
	@:iterations(1000000)
	public function opName():Dynamic {
		return doWork();
	}

	@:name("op.hot")
	@:warmup(100)
	@:iterations(1000000)
	public function opHot():String {
		return hot();
	}

	function doWork():Dynamic {
		return haxe.Json.parse('{"foo": "bar"}');
	}

	function hot():String {
		return haxe.Json.stringify({"foo": "bar"});
	}
}
