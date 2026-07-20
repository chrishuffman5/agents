# Blazor Diagnostics Reference

Troubleshooting guide for common Blazor issues across render modes.

---

## SignalR / Interactive Server Issues

### "Attempting to reconnect" banner appears frequently

- Check server memory -- circuits consume RAM. Scale or tune `DisconnectedCircuitMaxRetained`.
- Verify sticky sessions (load balancer affinity) are configured.
- Check SignalR WebSocket upgrade: proxy must not strip `Upgrade: websocket` headers.
- Enable detailed logging: `builder.Logging.SetMinimumLevel(LogLevel.Debug)` (dev only).

### UI freezes or is slow

- Long-running synchronous work blocks the circuit. Use `await Task.Yield()` to release, or offload to background services.
- Avoid large object graphs in component state -- SignalR serializes diffs.

### InvalidOperationException: current thread not associated with Dispatcher

- Component state mutated from non-Blazor thread (e.g., background timer).
- Fix: wrap with `await InvokeAsync(StateHasChanged)`.

### Circuit disconnects under load

- Each circuit holds the full component tree in memory. Monitor with `dotnet-counters`.
- Configure Azure SignalR Service backplane for multi-instance deployments.
- Reduce circuit memory by using `ShouldRender` and avoiding large collections in component state.

---

## WASM Download Issues

### Large initial download

```bash
dotnet publish -c Release
du -sh wwwroot/_framework/
```

- Use browser DevTools Network tab, filter by `.wasm` and `.dll` -- look for unintended large assemblies.
- Enable trimmer warnings via `<TrimmerRootDescriptor>`.
- Use lazy loading for assemblies not needed on startup.

### Trimming breaks functionality

- Reflection-heavy code (Newtonsoft.Json, EF Core) may fail after trimming.
- Annotate with `[DynamicDependency]` or `[RequiresUnreferencedCode]`.
- Set `<TrimMode>partial</TrimMode>` for less aggressive trimming.

### AOT build fails or takes too long

- AOT requires the Emscripten toolchain (installed automatically).
- Build times: 10-30 minutes for typical apps. CI may need larger runners.
- Validate with `dotnet publish -c Release -p:RunAOTCompilation=true`.

---

## Render Mode Conflicts

### "Cannot use interactive render mode" error

- Interactive modes require `AddInteractiveServerComponents()` / `AddInteractiveWebAssemblyComponents()` in `Program.cs`.
- Components in Static SSR pages using `@rendermode` must be isolated from the static tree.

### Child cannot be more interactive than parent

- A component rendered inside a Static SSR parent cannot declare `@rendermode InteractiveServer` in its own `.razor` file. The parent must apply the render mode at the usage site: `<Child @rendermode="InteractiveServer" />`.

### Mixed mode state sharing

- Components in different render modes cannot share state via DI (they run in different processes).
- Use APIs, browser storage, or server-side persistence for cross-mode communication.

---

## State Loss During Prerender

### Data fetched during prerender disappears

- Root cause: prerender runs in a temporary DI scope that is discarded.
- Fix: use `PersistentComponentState` (.NET 8/9) or `[PersistentState]` (.NET 10).

### API called twice on load

- Same root cause as state loss. The component initializes during prerender, then again during hydration.
- Fix: persist fetched data with `PersistentComponentState`. Or disable prerendering.

---

## Enhanced Navigation Issues

### Form submission causes full page reload

- Ensure `data-enhance` attribute is on the `<form>`.
- Verify `app.UseAntiforgery()` is in the middleware pipeline.

### Navigation breaks after swap

- Enhanced navigation patches the DOM. If JavaScript modifies the DOM outside Blazor's knowledge, patches may conflict.
- Disable enhanced navigation for problematic links: `data-enhance-nav="false"`.

---

## Debug Tools

### Browser Console

```javascript
Blazor.start({ logLevel: 4 });  // verbose Blazor logs
```

### Server-Side Profiling

```bash
dotnet-trace collect --process-id <PID>   # trace circuit activity
dotnet-counters monitor --process-id <PID>  # real-time metrics
```

### ASP.NET Core Health Checks

Add health checks for circuit and SignalR hub monitoring in production.

### WASM Binary Inspection

```bash
dotnet-wasm-tools  # global tool for inspecting WASM binary sections
```
