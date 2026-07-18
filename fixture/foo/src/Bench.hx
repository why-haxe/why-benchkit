package;

import why.benchkit.Runner;

class Bench {
	public static function main():Void {
		Runner.run([new MyLibSuite(), new Fibonacci()]);
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

class Fibonacci {
	public function new() {}

	public function fibonacci():Int {
		return doFibonacci(20);
	}

	static function doFibonacci(i:Int):Int {
		if (i < 2)
			return i;
		return doFibonacci(i - 1) + doFibonacci(i - 2);
	}
}
