# Blazor JS Interop Patterns

Patterns for calling JavaScript from .NET and .NET from JavaScript in Blazor.

---

## IJSRuntime (Universal)

Available in all render modes. All calls are asynchronous.

```csharp
@inject IJSRuntime JS

// Call JS from .NET
await JS.InvokeVoidAsync("console.log", "Hello from Blazor");
var result = await JS.InvokeAsync<string>("getDocumentTitle");
```

---

## Module Isolation (Recommended)

Load JS as ES modules to avoid global namespace pollution:

```csharp
private IJSObjectReference? _module;

protected override async Task OnAfterRenderAsync(bool firstRender)
{
    if (firstRender)
        _module = await JS.InvokeAsync<IJSObjectReference>(
            "import", "./js/myComponent.js");
}

await _module!.InvokeVoidAsync("init", elementRef);

public async ValueTask DisposeAsync()
{
    if (_module is not null)
        await _module.DisposeAsync();
}
```

```javascript
// wwwroot/js/myComponent.js
export function init(element) {
    element.focus();
}
```

---

## .NET from JavaScript (DotNetObjectReference)

```csharp
var objRef = DotNetObjectReference.Create(this);
await JS.InvokeVoidAsync("registerCallback", objRef);

[JSInvokable]
public void HandleCallback(string data) { /* ... */ }

// Always dispose
objRef.Dispose();
```

```javascript
function registerCallback(dotnetHelper) {
    dotnetHelper.invokeMethodAsync('HandleCallback', data);
}
```

---

## Synchronous Interop (WASM Only)

Zero async overhead. Only available when running in WebAssembly:

```csharp
if (JS is IJSInProcessRuntime inProcess)
{
    var value = inProcess.Invoke<string>("getTitle");
}
```

---

## .NET 10 New Methods

Eliminate common JS shim files:

```csharp
// Constructor: new ResizeObserver(callback)
var observer = await JS.InvokeConstructorAsync<IJSObjectReference>(
    "ResizeObserver", DotNetObjectReference.Create(this));

// Property read: navigator.userAgent
var ua = await JS.GetValueAsync<string>("navigator.userAgent");

// Property write: document.title = "My Page"
await JS.SetValueAsync("document.title", "My Page");
```

All three support dotted-path traversal (e.g., `"window.history.length"`).

---

## Key Rules

1. **Call JS only in OnAfterRenderAsync** -- DOM does not exist during `OnInitialized`.
2. **Always dispose references** -- `IJSObjectReference` and `DotNetObjectReference` are GC roots.
3. **Use module isolation** -- Avoids global namespace conflicts and enables tree shaking.
4. **Guard against prerender** -- JS interop fails during prerender. Check `firstRender` or use `RendererInfo.IsInteractive` (.NET 9+).
