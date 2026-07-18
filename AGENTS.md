# Agent guidelines

## Haxe coding style

Prefer modern Haxe syntax where it fits:

- Use `final` for readonly fields and locals that are not reassigned.
- Prefer arrow function expressions (`() -> …`) for short callbacks and lambdas.
- Prefer named-argument function types (`(name:Type) -> Ret`) over positional-only forms when declaring function types.
- Use type-safe values from `why-unit` library where applicable

### Explicit member types

All member functions must declare argument and return types explicitly.

Exception: lambdas / closures may omit types when they are inferred from context.

```haxe
// ✅ GOOD
public function measure(fn:() -> Void, ?opts:MeasureOptions):MeasureResult { … }

final sink = (v:Any) -> { /* … */ };
items.map(x -> x * 2);

// ❌ BAD — untyped member
public function measure(fn, ?opts) { … }
```
