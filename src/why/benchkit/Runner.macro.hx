package why.benchkit;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

/**
	Macro implementation for `Runner.run` (see `Runner.hx`).
**/
class Runner {
	public static function run(suites:Expr):Expr {
		final values = switch suites.expr {
			case EArrayDecl(v):
				v;
			case _:
				Context.error('why.benchkit.Runner.run expects an array literal of suite instances', suites.pos);
		};

		final suiteBlocks:Array<Expr> = [];
		for (i => suiteExpr in values) {
			suiteBlocks.push(buildSuiteBlock(suiteExpr, i));
		}

		return macro {
			final __reporters = why.benchkit.Runner.loadReporters();
			final __suiteResults:Array<why.benchkit.SuiteResult> = [];
			$b{suiteBlocks};
			why.benchkit.Runner.finish(__suiteResults, __reporters);
		};
	}

	static function buildSuiteBlock(suiteExpr:Expr, index:Int):Expr {
		final classType = switch Context.follow(Context.typeof(suiteExpr)) {
			case TInst(c, _):
				c.get();
			case _:
				Context.error('why.benchkit.Runner.run: suite values must be class instances', suiteExpr.pos);
		};

		final suiteName = metaString(classType.meta, ':name') ?? classType.name;
		final suiteIdent = '__suite$index';
		final resultsIdent = '__results$index';

		final measureExprs:Array<Expr> = [];
		for (field in collectMeasureFields(classType)) {
			measureExprs.push(buildMeasurePush(suiteIdent, resultsIdent, field));
		}

		return macro {
			final $suiteIdent = $suiteExpr;
			final $resultsIdent:Array<why.benchkit.MeasureResult> = [];
			$b{measureExprs};
			__suiteResults.push({
				name: $v{suiteName},
				results: $i{resultsIdent},
			});
		};
	}

	static function buildMeasurePush(suiteIdent:String, resultsIdent:String, field:ClassField):Expr {
		final measureName = metaString(field.meta, ':name') ?? field.name;
		final warmup = metaInt(field.meta, ':warmup');
		final iterations = metaInt(field.meta, ':iterations');

		final optsFields:Array<ObjectField> = [
			{field: 'name', expr: macro $v{measureName}},
		];
		if (warmup != null)
			optsFields.push({field: 'warmup', expr: macro $v{warmup}});
		if (iterations != null)
			optsFields.push({field: 'iterations', expr: macro $v{iterations}});

		final opts:Expr = {expr: EObjectDecl(optsFields), pos: field.pos};
		final methodName = field.name;
		final call = macro $i{suiteIdent}.$methodName();
		// Void cannot be used as a value; valued returns must reach Sink via Measure.
		final fn:Expr = isVoidReturn(field)
			? macro () -> {
				$call;
				null;
			}
			: macro () -> $call;

		return macro $i{resultsIdent}.push(why.benchkit.Measure.run($fn, $opts));
	}

	static function isVoidReturn(field:ClassField):Bool {
		return switch Context.follow(field.type) {
			case TFun(_, ret):
				switch Context.follow(ret) {
					case TAbstract(_.get() => {pack: [], name: "Void"}, _):
						true;
					case _:
						false;
				}
			case _:
				false;
		};
	}

	static function collectMeasureFields(classType:ClassType):Array<ClassField> {
		final out:Array<ClassField> = [];
		final seen = new Map<String, Bool>();
		var current:Null<ClassType> = classType;
		while (current != null) {
			for (field in current.fields.get()) {
				if (seen.exists(field.name))
					continue;
				seen.set(field.name, true);
				if (!field.isPublic)
					continue;
				switch field.kind {
					case FMethod(_):
						ensureNoRequiredArgs(field);
						out.push(field);
					case _:
				}
			}
			current = current.superClass != null ? current.superClass.t.get() : null;
		}
		return out;
	}

	static function ensureNoRequiredArgs(field:ClassField):Void {
		switch Context.follow(field.type) {
			case TFun(args, _):
				for (arg in args) {
					if (!arg.opt)
						Context.error('why.benchkit: measure method ${field.name} must take no required arguments', field.pos);
				}
			case _:
				Context.error('why.benchkit: unexpected type for measure method ${field.name}', field.pos);
		}
	}

	static function metaString(meta:MetaAccess, name:String):Null<String> {
		final found = meta.extract(name);
		if (found.length == 0)
			return null;
		final params = found[0].params;
		if (params == null || params.length != 1)
			Context.error('why.benchkit: @$name expects a single string argument', found[0].pos);
		return switch params[0].expr {
			case EConst(CString(s)):
				s;
			case _:
				Context.error('why.benchkit: @$name expects a string argument', params[0].pos);
		};
	}

	static function metaInt(meta:MetaAccess, name:String):Null<Int> {
		final found = meta.extract(name);
		if (found.length == 0)
			return null;
		final params = found[0].params;
		if (params == null || params.length != 1)
			Context.error('why.benchkit: @$name expects a single int argument', found[0].pos);
		return switch params[0].expr {
			case EConst(CInt(v)):
				Std.parseInt(v);
			case _:
				Context.error('why.benchkit: @$name expects an int argument', params[0].pos);
		};
	}
}
